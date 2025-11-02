require 'json'
require 'fileutils'

module Streamripper
  class RawStreamReparser
    def initialize(scan_dir)
      @scan_dir = scan_dir
      @raw_file = File.join(scan_dir, 'raw_stream.bin')
      @analysis_file = File.join(scan_dir, 'analysis.json')
      @frames_dir = File.join(scan_dir, 'frames')
      
      raise "Scan directory not found: #{scan_dir}" unless Dir.exist?(scan_dir)
      raise "raw_stream.bin not found: #{@raw_file}" unless File.exist?(@raw_file)
    end

    def reparse
      puts "Re-parsing: #{@raw_file}"
      
      # Read raw stream
      raw_data = File.binread(@raw_file)
      puts "Raw file size: #{raw_data.length} bytes\n"
      
      # Parse RTSP-over-TCP framing
      packets = parse_rtsp_packets(raw_data)
      puts "Total packets parsed: #{packets.length}"
      
      # Determine video SSRC
      video_ssrc = find_video_ssrc(packets)
      puts "Video SSRC: #{video_ssrc}\n"
      
      # Filter packets by SSRC
      video_packets = packets.select { |p| p[:ssrc] == video_ssrc }
      audio_packets = packets.reject { |p| p[:ssrc] == video_ssrc }
      
      puts "Packet filtering:"
      puts "  Video packets: #{video_packets.length}"
      puts "  Audio packets: #{audio_packets.length}"
      puts "  Ratio: #{(video_packets.length.to_f / packets.length * 100).round(1)}% video\n"
      
      # Regenerate analysis.json
      puts "Regenerating analysis.json..."
      regenerate_analysis(video_packets)
      
      # Regenerate frame files
      puts "Regenerating frame files..."
      regenerate_frames(video_packets)
      
      puts "\n✓ Re-parsing complete!"
    end

    private

    def parse_rtsp_packets(data)
      packets = []
      offset = 0
      
      while offset < data.length
        break if offset + 4 > data.length
        
        marker = data[offset].ord
        break if marker != 0x24  # '$'
        
        channel = data[offset + 1].ord
        length = data[offset+2..offset+3].unpack('n')[0]
        offset += 4
        
        break if offset + 12 > data.length
        
        rtp_header = data[offset..offset+11]
        pt = rtp_header[1].ord & 0x7f
        ssrc = rtp_header[8..11].unpack('N')[0]
        
        packets << {
          offset: offset - 4,
          channel: channel,
          length: length,
          pt: pt,
          ssrc: ssrc,
          data: data[offset..offset+length-1]
        }
        
        offset += length
      end
      
      packets
    end

    def find_video_ssrc(packets)
      ssrc_counts = {}
      packets.each do |p|
        if p[:pt] == 96  # H.264
          ssrc = p[:ssrc]
          ssrc_counts[ssrc] = (ssrc_counts[ssrc] || 0) + 1
        end
      end
      
      ssrc_counts.max_by { |_, count| count }&.first
    end

    def regenerate_analysis(packets)
      # The analysis.json already has correct wallclock times from the original capture
      # We don't regenerate it because we can't reconstruct wallclock times from raw RTP data
      # The SSRC filtering is applied during frame file regeneration instead

      current_analysis = JSON.parse(File.read(@analysis_file)) if File.exist?(@analysis_file)
      puts "  Keeping existing analysis.json (#{current_analysis&.length || 0} packets with wallclock times)"
    end

    def regenerate_frames(packets)
      # Clear old frames
      FileUtils.rm_rf(@frames_dir)
      FileUtils.mkdir_p(@frames_dir)

      # Group packets by RTP timestamp
      frames_by_rtp = {}
      packets.each do |pkt|
        rtp_header = pkt[:data][0..11]
        rtp_ts = rtp_header[4..7].unpack('N')[0]

        frames_by_rtp[rtp_ts] ||= []
        frames_by_rtp[rtp_ts] << pkt
      end

      # Write frame files with proper H.264 defragmentation
      frame_number = 1
      frames_by_rtp.each do |rtp_ts, frame_packets|
        frame_data = defragment_h264_frame(frame_packets)
        frame_file = File.join(@frames_dir, "frame#{frame_number.to_s.rjust(5, '0')}.bin")
        File.binwrite(frame_file, frame_data)
        frame_number += 1
      end

      puts "  Wrote #{frame_number - 1} frame files"
    end

    def defragment_h264_frame(frame_packets)
      # De-fragment H.264 NAL units from RTP packets
      result = ''
      current_nal = nil

      frame_packets.each do |pkt|
        rtp_data = pkt[:data]
        payload = rtp_data[12..-1]  # Skip RTP header
        next if !payload || payload.length < 1

        first_byte = payload[0].ord
        nal_unit_type = first_byte & 0x1F

        if nal_unit_type == 28  # FU-A (Fragmentation Unit A)
          # Handle fragmented NAL unit
          if payload.length < 2
            next
          end

          fu_header = payload[1].ord
          nal_type = fu_header & 0x1F
          start_bit = (fu_header >> 7) & 0x1
          end_bit = (fu_header >> 6) & 0x1
          fragment_data = payload[2..-1]

          # Skip FU-A fragments with reserved NAL types (>= 30)
          if nal_type >= 30
            next
          end

          if start_bit == 1
            # Start of fragmented NAL unit
            nri = (first_byte >> 5) & 0x3
            nal_header = ((nri << 5) | nal_type).chr
            current_nal = "\x00\x00\x01" + nal_header + fragment_data
          elsif current_nal && fragment_data
            # Continuation of fragmented NAL unit
            current_nal += fragment_data
          elsif !current_nal && start_bit == 0
            # Orphaned fragment - skip it
            next
          end

          if end_bit == 1 && current_nal
            # End of fragmented NAL unit
            result += current_nal
            current_nal = nil
          end
        else
          # Single NAL unit (not fragmented)
          result += "\x00\x00\x01" + payload
        end
      end

      # Add any remaining fragmented NAL unit
      result += current_nal if current_nal

      result
    end
  end
end

