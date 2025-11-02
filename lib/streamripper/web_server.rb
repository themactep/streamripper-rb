require 'socket'
require 'json'
require 'base64'
require_relative 'rtsp_fetcher'
require_relative 'packet_analyzer'

module Streamripper
  class WebServer
    def initialize(port = 8080)
      @port = port
      @server = TCPServer.new('localhost', port)
    end

    def start
      puts "🌐 Streamripper Web UI starting on http://localhost:#{@port}"
      puts "Press Ctrl+C to stop"

      trap('INT') { @server.close; exit }

      loop do
        client = @server.accept
        Thread.new(client) { |c| handle_request(c) }
      end
    end

    private

    def handle_request(client)
      request_line = client.gets
      return unless request_line

      method, path, _ = request_line.split
      headers = {}

      while (line = client.gets.chomp) != ''
        key, value = line.split(': ', 2)
        headers[key] = value
      end

      body = ''
      if headers['Content-Length']
        body = client.read(headers['Content-Length'].to_i)
      end

      response = route_request(method, path, headers, body)
      client.print response
      client.close
    rescue => e
      error_response = "HTTP/1.1 500 Internal Server Error\r\nContent-Type: application/json\r\n\r\n"
      error_response += { error: e.message }.to_json
      client.print error_response
      client.close
    end

    def route_request(method, path, headers, body)
      # Extract base path without query string
      base_path = path.split('?')[0]

      case base_path
      when '/'
        http_response('text/html', render_ui)
      when '/api/capture'
        if method == 'POST'
          data = JSON.parse(body)
          rtsp_url = data['rtsp_url']
          duration = data['duration'].to_i

          begin
            capture_data = capture_stream(rtsp_url, duration)
            http_response('application/json', capture_data.to_json)
          rescue => e
            http_error(400, { error: e.message }.to_json)
          end
        else
          http_error(405, { error: 'Method not allowed' }.to_json)
        end
      when /^\/api\/frame-hex/
        query = path.split('?', 2)[1]
        if query
          params = parse_query(query)
          frame_base64 = params['frame']

          if frame_base64
            frame_data = Base64.decode64(frame_base64)
            hex_dump = generate_hex_dump(frame_data)
            http_response('application/json', { hex: hex_dump }.to_json)
          else
            http_error(400, { error: 'No frame data provided' }.to_json)
          end
        else
          http_error(400, { error: 'No frame data provided' }.to_json)
        end
      when /^\/api\/scans/
        scans = get_previous_scans
        http_response('application/json', { scans: scans }.to_json)
      when /^\/api\/load-scan/
        query = path.split('?', 2)[1]
        if query
          params = parse_query(query)
          scan_id = params['scan_id']
          host = params['host']

          if scan_id && host
            begin
              scan_data = load_scan_data(host, scan_id)
              http_response('application/json', scan_data.to_json)
            rescue => e
              http_error(400, { error: e.message }.to_json)
            end
          else
            http_error(400, { error: 'Missing scan_id or host' }.to_json)
          end
        else
          http_error(400, { error: 'Missing parameters' }.to_json)
        end
      when /^\/api\/reparse/
        if method == 'POST'
          query = path.split('?', 2)[1]
          if query
            params = parse_query(query)
            scan_id = params['scan_id']
            host = params['host']

            if scan_id && host
              begin
                reparse_scan(host, scan_id)
                http_response('application/json', { status: 'success', message: 'Reparse complete' }.to_json)
              rescue => e
                http_error(400, { error: e.message }.to_json)
              end
            else
              http_error(400, { error: 'Missing scan_id or host' }.to_json)
            end
          else
            http_error(400, { error: 'Missing parameters' }.to_json)
          end
        else
          http_error(405, { error: 'Method not allowed' }.to_json)
        end
      when /^\/api\/list-scans/
        begin
          scans = list_all_scans
          http_response('application/json', { status: 'success', scans: scans }.to_json)
        rescue => e
          http_error(400, { error: e.message }.to_json)
        end
      when /^\/thumbnails\//
        # Serve thumbnail images
        thumbnail_path = path.sub(/^\/thumbnails\//, '')
        file_path = File.join('logs/streams', thumbnail_path)
        if File.exist?(file_path)
          content = File.binread(file_path)
          http_response('image/jpeg', content)
        else
          http_error(404, { error: 'Thumbnail not found' }.to_json)
        end
      when /^\/logs\//
        # Serve files from logs directory
        file_path = File.join(Dir.pwd, path)
        if File.exist?(file_path) && File.file?(file_path)
          content = File.binread(file_path)
          content_type = case File.extname(file_path)
                         when '.mp4' then 'video/mp4'
                         when '.h264' then 'video/mp4'  # H.264 raw stream
                         when '.json' then 'application/json'
                         when '.bin' then 'application/octet-stream'
                         else 'application/octet-stream'
                         end
          "HTTP/1.1 200 OK\r\nContent-Type: #{content_type}\r\nContent-Length: #{content.bytesize}\r\nConnection: close\r\n\r\n#{content}"
        else
          http_error(404, { error: 'File not found' }.to_json)
        end
      else
        http_error(404, { error: 'Not found' }.to_json)
      end
    end

    def parse_query(query_string)
      params = {}
      query_string.split('&').each do |pair|
        key, value = pair.split('=', 2)
        params[key] = URI.decode_www_form_component(value) if value
      end
      params
    end

    def http_response(content_type, body)
      "HTTP/1.1 200 OK\r\nContent-Type: #{content_type}\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
    end

    def http_error(status, body)
      status_text = { 400 => 'Bad Request', 404 => 'Not Found', 405 => 'Method Not Allowed', 500 => 'Internal Server Error' }[status]
      "HTTP/1.1 #{status} #{status_text}\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
    end

    def capture_stream(rtsp_url, duration)
      require_relative 'output_manager'

      # Extract host from RTSP URL for directory naming
      uri = URI.parse(rtsp_url)
      host_part = "#{uri.host}_#{uri.path.gsub('/', '_')}"

      # Initialize output manager
      output_mgr = OutputManager.new(rtsp_url)

      require_relative 'stream_saver'

      fetcher = RTSPFetcher.new(rtsp_url)
      analyzer = PacketAnalyzer.new
      packets_data = []

      # Initialize stream saver for raw packets
      raw_stream_file = output_mgr.get_output_path('raw_stream.bin')
      saver = StreamSaver.new(raw_stream_file)

      start_time = Time.now
      packet_count = 0

      packets_dir = File.join(output_mgr.run_dir, 'packets')
      FileUtils.mkdir_p(packets_dir)

      video_ssrc = nil
      ssrc_sample_count = 0
      ssrc_counts = {}
      all_packets_temp = []  # Store all packets for re-processing

      fetcher.fetch do |packet|
        analysis = analyzer.analyze(packet)

        # Store all packets for later processing
        all_packets_temp << { analysis: analysis, packet: packet }

        # Save ALL packets to raw_stream.bin (for forensic preservation)
        saver.save_packet(packet)

        # Determine video SSRC from first 100 packets
        if ssrc_sample_count < 100
          if analysis[:payload_type_code] == 96
            ssrc = analysis[:ssrc]
            ssrc_counts[ssrc] = (ssrc_counts[ssrc] || 0) + 1
          end
          ssrc_sample_count += 1

          if ssrc_sample_count == 100
            video_ssrc = ssrc_counts.max_by { |_, count| count }&.first
          end
        end

        if Time.now - start_time >= duration
          break
        end
      end

      # Now process all packets with known video SSRC
      all_packets_temp.each do |pkt_data|
        analysis = pkt_data[:analysis]
        packet = pkt_data[:packet]

        # Only process video packets (by SSRC) for analysis and individual packet files
        if video_ssrc && analysis[:ssrc] == video_ssrc
          packets_data << {
            analysis: analysis,
            payload: packet[:payload]
          }

          packet_count += 1

          # Save individual packet binary file (numbered from 1)
          packet_file = File.join(packets_dir, "packet#{packet_count.to_s.rjust(6, '0')}.bin")
          File.binwrite(packet_file, packet[:raw_packet])
        end
      end

      saver.close
      puts "Saved #{packet_count} individual packets to packets/ directory"

      # Aggregate frames (use payloads from memory)
      frames = aggregate_frames(packets_data)

      # Save analysis data (WITHOUT payloads - only metadata)
      analysis_file = output_mgr.get_output_path('analysis.json')
      File.write(analysis_file, packets_data.map { |p| p[:analysis] }.to_json)

      # Save individual frame binary files
      require_relative 'packet_extractor'
      frames_dir = File.join(output_mgr.run_dir, 'frames')
      discarded_dir = File.join(output_mgr.run_dir, 'discarded_packets')
      FileUtils.mkdir_p(frames_dir)
      FileUtils.mkdir_p(discarded_dir)

      # For H.264, we need to preserve packet order and de-fragment properly
      # Group packets by RTP timestamp to identify frame boundaries

      frames_by_rtp = {}
      frame_order = []
      discarded_packets = []
      found_sps = false

      packets_data.each do |pkt_data|
        payload = pkt_data[:payload]
        analysis = pkt_data[:analysis]

        # Check if packet passes all filters
        is_valid = true
        discard_reason = nil

        # Filter 2: Check if packet has valid payload
        if is_valid && (!payload || payload.length < 1)
          is_valid = false
          discard_reason = "Empty/invalid payload"
        end

        # Filter 3: Check for reserved NAL types
        if is_valid
          first_byte = payload[0].ord
          nal_unit_type = first_byte & 0x1F

          if nal_unit_type >= 30
            is_valid = false
            discard_reason = "Reserved NAL type (#{nal_unit_type})"
          end
        end

        # Filter 4: Track SPS packets to know when stream starts
        if is_valid
          first_byte = payload[0].ord
          nal_unit_type = first_byte & 0x1F

          if nal_unit_type == 7  # SPS
            found_sps = true
          end
        end

        # If packet didn't pass filters, add to discarded
        if !is_valid
          pkt_data[:discard_reason] = discard_reason
          discarded_packets << pkt_data
          next
        end

        # Packet passed all filters, add to frames
        rtp_ts = analysis[:rtp_timestamp_raw]
        unless frames_by_rtp.key?(rtp_ts)
          frames_by_rtp[rtp_ts] = []
          frame_order << rtp_ts
        end
        frames_by_rtp[rtp_ts] << pkt_data
      end

      # Create individual frame files for each RTP timestamp
      # Also create a complete H.264 stream with SPS/PPS at the beginning
      frame_number = 1
      sps_pps_data = nil
      is_first_frame = true
      frame_packet_ranges = []

      frame_order.each do |rtp_ts|
        frame_packets = frames_by_rtp[rtp_ts]
        frame_data = defragment_h264_frame(frame_packets, is_first_frame)

        # Extract and save SPS/PPS from first frame
        if sps_pps_data.nil?
          sps_pps_data = extract_sps_pps(frame_data)
        end

        # Track packet range for this frame
        packet_numbers = frame_packets.map { |p| p[:analysis][:packet_number] }.sort
        first_pkt = packet_numbers.first
        last_pkt = packet_numbers.last
        frame_packet_ranges << {
          frame_number: frame_number,
          first_packet: first_pkt,
          last_packet: last_pkt,
          packet_count: packet_numbers.length
        }

        # Save individual frame file
        frame_filename = format("frame%05d.bin", frame_number)
        frame_filepath = File.join(frames_dir, frame_filename)
        File.binwrite(frame_filepath, frame_data)
        frame_number += 1
        is_first_frame = false
      end

      # Save frame packet ranges metadata
      frame_ranges_file = output_mgr.get_output_path('frame_packet_ranges.json')
      File.write(frame_ranges_file, frame_packet_ranges.to_json)

      # Save discarded packets for analysis
      save_discarded_packets(discarded_packets, discarded_dir)

      # Save audio packets separately if any exist
      audio_packets = discarded_packets.select { |p| p[:discard_reason]&.include?("Audio") }
      if audio_packets.length > 0
        save_audio_packets(audio_packets, discarded_dir)
      end

      # Create complete H.264 stream with SPS/PPS at the beginning
      h264_stream = defragment_h264_stream(packets_data)

      # Calculate actual frame rate from RTP timestamps
      rtp_timestamps = packets_data.map { |p| p[:analysis][:rtp_timestamp_raw] }.uniq
      actual_fps = calculate_frame_rate(rtp_timestamps, duration)

      # Generate playable MP4 file from the complete H.264 stream
      generate_mp4_from_h264_stream(h264_stream, output_mgr.run_dir, actual_fps)

      # Extract host and scan_id from paths
      # stream_dir: logs/streams/192_168_88_31_ch0
      # run_dir: logs/streams/192_168_88_31_ch0/20251101_110015
      host = File.basename(output_mgr.stream_dir)
      scan_id = File.basename(output_mgr.run_dir)

      {
        status: 'success',
        packet_count: packet_count,
        frame_count: frames.length,
        duration: (Time.now - start_time).round(2),
        frames: frames,
        host: host,
        scan_id: scan_id
      }
    end

    def aggregate_frames(packets_data)
      frames_by_rtp = {}
      frame_order = []

      packets_data.each do |pkt_data|
        packet = pkt_data[:analysis]
        rtp_ts = packet[:rtp_timestamp_raw]
        unless frames_by_rtp.key?(rtp_ts)
          frames_by_rtp[rtp_ts] = []
          frame_order << rtp_ts
        end
        frames_by_rtp[rtp_ts] << pkt_data
      end

      frame_order.map.with_index do |rtp_ts, idx|
        frame_packets = frames_by_rtp[rtp_ts]

        # Concatenate packet payloads
        frame_payload = frame_packets.map { |p| p[:payload] || '' }.join

        {
          frame_number: idx + 1,
          frame_type: frame_packets.first[:analysis][:frame_type].split('(')[0],
          packet_count: frame_packets.length,
          total_size: frame_packets.sum { |p| p[:analysis][:raw_packet_size] },
          rtp_timestamp: rtp_ts,
          first_packet: frame_packets.first[:analysis][:packet_number],
          last_packet: frame_packets.last[:analysis][:packet_number],
          deviation: frame_packets.first[:analysis][:timestamp_deviation_us],
          payload: Base64.encode64(frame_payload).chomp
        }
      end
    end

    def generate_hex_dump(data, bytes_per_line = 16)
      lines = []
      data.each_byte.each_slice(bytes_per_line).with_index do |bytes, line_idx|
        offset = line_idx * bytes_per_line
        hex_part = bytes.map { |b| format('%02X', b) }.join(' ')
        ascii_part = bytes.map { |b| (32..126).include?(b) ? b.chr : '.' }.join
        lines << format('%08X  %-48s  %s', offset, hex_part, ascii_part)
      end
      lines.join("\n")
    end

    def render_ui
      template_file = File.join(File.dirname(__FILE__), 'ui_template.html')
      File.read(template_file)
    end

    def load_scan_data(host, scan_id)
      analysis_json = File.join('logs/streams', host, scan_id, 'analysis.json')

      raise "Scan not found: #{scan_id}" unless File.exist?(analysis_json)

      data = JSON.parse(File.read(analysis_json))

      # Calculate duration from wallclock timestamps
      duration = 0
      if data.length > 1
        first_time = data.first['wallclock_time_us']
        last_time = data.last['wallclock_time_us']
        duration = ((last_time - first_time) / 1_000_000.0).round(2)
      end

      # Build packet lookup by packet number for metadata
      packet_by_number = {}
      data.each { |p| packet_by_number[p['packet_number']] = p }

      # Aggregate frames with host and scan_id for frame file loading
      frames = aggregate_frames_from_data(data, host, scan_id, packet_by_number)

      # Generate thumbnail if it doesn't exist
      generate_thumbnail(host, scan_id, frames)

      {
        status: 'success',
        packet_count: data.length,
        frame_count: frames.length,
        duration: duration,
        frames: frames,
        host: host,
        scan_id: scan_id
      }
    end

    def generate_thumbnail(host, scan_id, frames)
      # Generate a thumbnail from the first I-frame
      thumbnail_file = File.join('logs/streams', host, scan_id, 'thumbnail.jpg')
      return if File.exist?(thumbnail_file)  # Already exists

      # Find first I-frame
      i_frame = frames.find { |f| f[:frame_type] == 'I-frame' }
      return unless i_frame

      # Get the frame file
      frames_dir = File.join('logs/streams', host, scan_id, 'frames')
      frame_file = File.join(frames_dir, "frame#{i_frame[:frame_number].to_s.rjust(5, '0')}.bin")
      return unless File.exist?(frame_file)

      # Create a temporary H.264 file with SPS/PPS headers for ffmpeg
      temp_h264 = File.join('logs/streams', host, scan_id, '.temp_thumb.h264')
      begin
        # Find SPS and PPS frames
        sps_frame = frames.find { |f| f[:frame_type] == 'SPS' }
        pps_frame = frames.find { |f| f[:frame_type] == 'PPS' }

        # Build H.264 file with SPS, PPS, and I-frame
        h264_data = ''
        h264_data += File.binread(File.join(frames_dir, "frame#{sps_frame[:frame_number].to_s.rjust(5, '0')}.bin")) if sps_frame
        h264_data += File.binread(File.join(frames_dir, "frame#{pps_frame[:frame_number].to_s.rjust(5, '0')}.bin")) if pps_frame
        h264_data += File.binread(frame_file)

        File.binwrite(temp_h264, h264_data)

        # Use ffmpeg to convert H.264 to JPEG thumbnail
        system("ffmpeg -i #{temp_h264} -vframes 1 -q:v 5 -y #{thumbnail_file} 2>/dev/null")

        # Clean up temp file
        File.delete(temp_h264) if File.exist?(temp_h264)
      rescue => e
        # Clean up on error
        File.delete(temp_h264) if File.exist?(temp_h264)
      end
    end

    def list_all_scans
      # List all available scans with metadata
      scans = []
      streams_dir = 'logs/streams'

      return scans unless Dir.exist?(streams_dir)

      Dir.glob("#{streams_dir}/*").each do |host_dir|
        host = File.basename(host_dir)

        Dir.glob("#{host_dir}/*").each do |scan_dir|
          next unless File.directory?(scan_dir)

          scan_id = File.basename(scan_dir)
          analysis_file = File.join(scan_dir, 'analysis.json')
          thumbnail_file = File.join(scan_dir, 'thumbnail.jpg')

          next unless File.exist?(analysis_file)

          begin
            data = JSON.parse(File.read(analysis_file))

            # Calculate duration
            duration = 0
            if data.length > 1
              first_time = data.first['wallclock_time_us']
              last_time = data.last['wallclock_time_us']
              duration = ((last_time - first_time) / 1_000_000.0).round(2)
            end

            # Check if thumbnail exists
            has_thumbnail = File.exist?(thumbnail_file)

            scans << {
              host: host,
              scan_id: scan_id,
              packet_count: data.length,
              frame_count: data.map { |p| p['rtp_timestamp_raw'] }.uniq.length,
              duration: duration,
              has_thumbnail: has_thumbnail,
              thumbnail_url: has_thumbnail ? "/thumbnails/#{host}/#{scan_id}/thumbnail.jpg" : nil
            }
          rescue
            # Skip scans with errors
          end
        end
      end

      # Sort by scan_id (which encodes the timestamp), newest first
      scans.sort_by { |s| s[:scan_id] }.reverse
    end

    def reparse_scan(host, scan_id)
      # Reparse the raw stream data and regenerate all analysis files
      scan_dir = File.join('logs/streams', host, scan_id)

      raise "Scan directory not found: #{scan_dir}" unless Dir.exist?(scan_dir)

      # Use the raw_stream_reparser to regenerate everything
      reparser = RawStreamReparser.new(scan_dir)
      reparser.reparse

      true
    end

    def aggregate_frames_from_data(packets, host = nil, scan_id = nil, packet_by_number = nil)
      # If we have frame files, use them as the source of truth
      if host && scan_id
        frames_dir = File.join('logs/streams', host, scan_id, 'frames')
        if Dir.exist?(frames_dir)
          frame_files = Dir.glob("#{frames_dir}/frame*.bin").sort

          # Load frame packet ranges metadata if available
          ranges_file = File.join('logs/streams', host, scan_id, 'frame_packet_ranges.json')
          frame_ranges = {}
          if File.exist?(ranges_file)
            JSON.parse(File.read(ranges_file)).each do |r|
              frame_ranges[r['frame_number']] = r
            end
          end

          return frame_files.map.with_index do |frame_file, idx|
            frame_number = idx + 1
            frame_payload = File.binread(frame_file)
            frame_file_size = frame_payload.bytesize

            # Extract frame type from H.264 NAL unit
            frame_type = 'Unknown'
            if frame_payload.length >= 4 && frame_payload[0..2] == "\x00\x00\x01"
              nal_type = frame_payload[3].ord & 0x1F
              frame_type = case nal_type
                           when 5 then 'I-frame'
                           when 1 then 'P-frame'
                           when 7 then 'SPS'
                           when 8 then 'PPS'
                           else "NAL-#{nal_type}"
                           end
            end

            # Get packet range from metadata
            range_data = frame_ranges[frame_number] || {}

            # Get RTP timestamp and deviation from first packet in frame
            rtp_timestamp = 0
            deviation = 0
            if range_data['first_packet'] && packet_by_number
              first_pkt = packet_by_number[range_data['first_packet']]
              if first_pkt
                rtp_timestamp = first_pkt['rtp_timestamp_raw'] || 0
                deviation = first_pkt['timestamp_deviation_us'] || 0
              end
            end

            {
              frame_number: frame_number,
              frame_type: frame_type,
              packet_count: range_data['packet_count'] || 1,
              total_size: frame_file_size,
              rtp_timestamp: rtp_timestamp,
              first_packet: range_data['first_packet'] || 0,
              last_packet: range_data['last_packet'] || 0,
              deviation: deviation,
              payload: Base64.encode64(frame_payload).chomp
            }
          end
        end
      end

      # Fallback: group by RTP timestamp if no frame files
      frames_by_rtp = {}
      frame_order = []

      packets.each do |packet|
        rtp_ts = packet['rtp_timestamp_raw']
        unless frames_by_rtp.key?(rtp_ts)
          frames_by_rtp[rtp_ts] = []
          frame_order << rtp_ts
        end
        frames_by_rtp[rtp_ts] << packet
      end

      frame_order.map.with_index do |rtp_ts, idx|
        frame_packets = frames_by_rtp[rtp_ts]
        frame_number = idx + 1

        {
          frame_number: frame_number,
          frame_type: frame_packets.first['frame_type'].split('(')[0],
          packet_count: frame_packets.length,
          total_size: 0,
          rtp_timestamp: rtp_ts,
          first_packet: frame_packets.first['packet_number'],
          last_packet: frame_packets.last['packet_number'],
          deviation: frame_packets.first['timestamp_deviation_us'],
          payload: Base64.encode64('').chomp
        }
      end
    end

    def get_previous_scans
      scans_dir = 'logs/streams'
      return [] unless Dir.exist?(scans_dir)

      scans = []
      Dir.glob("#{scans_dir}/*").each do |host_dir|
        next unless File.directory?(host_dir)

        Dir.glob("#{host_dir}/*").each do |scan_dir|
          next unless File.directory?(scan_dir)

          analysis_json = File.join(scan_dir, 'analysis.json')
          analysis_html = File.join(scan_dir, 'analysis.html')

          if File.exist?(analysis_json)
            begin
              data = JSON.parse(File.read(analysis_json))
              timestamp = File.mtime(analysis_json).to_i

              scans << {
                timestamp: timestamp,
                time: Time.at(timestamp).strftime('%Y-%m-%d %H:%M:%S'),
                host: File.basename(host_dir),
                scan_id: File.basename(scan_dir),
                packet_count: data.length,
                html_url: analysis_html.sub('logs/', ''),
                json_url: analysis_json.sub('logs/', '')
              }
            rescue => e
              # Skip invalid scans
            end
          end
        end
      end

      scans.sort_by { |s| -s[:timestamp] }.take(20)
    end

    def save_audio_packets(audio_packets, discarded_dir)
      # Save audio packets to separate subdirectory
      audio_dir = File.join(discarded_dir, 'audio')
      FileUtils.mkdir_p(audio_dir)

      # Save raw audio data
      audio_raw_file = File.join(audio_dir, 'audio_packets.bin')
      File.open(audio_raw_file, 'wb') do |f|
        audio_packets.each do |pkt_data|
          payload = pkt_data[:payload]
          f.write(payload) if payload
        end
      end

      # Save audio packet analysis as JSON
      audio_json_file = File.join(audio_dir, 'audio_packets.json')
      audio_data = audio_packets.map do |p|
        analysis = p[:analysis].dup
        analysis[:discard_reason] = p[:discard_reason]
        analysis
      end
      File.write(audio_json_file, JSON.pretty_generate(audio_data))

      # Save audio summary
      audio_summary_file = File.join(audio_dir, 'summary.txt')
      File.open(audio_summary_file, 'w') do |f|
        f.puts "Audio Packets Analysis"
        f.puts "=" * 50
        f.puts "Total audio packets: #{audio_packets.length}"
        f.puts ""

        # Calculate total audio data size
        total_size = audio_packets.sum { |p| p[:payload]&.length || 0 }
        f.puts "Total audio data: #{total_size} bytes"
        f.puts ""

        # Audio codec info
        if audio_packets.length > 0
          first_packet = audio_packets.first
          codec = first_packet[:analysis][:packet_type]
          f.puts "Audio Codec: #{codec}"
          f.puts "Payload Type: #{first_packet[:analysis][:payload_type_code]}"
          f.puts ""
        end

        # RTP timestamp info
        rtp_timestamps = audio_packets.map { |p| p[:analysis][:rtp_timestamp_raw] }.uniq
        f.puts "Unique RTP Timestamps: #{rtp_timestamps.length}"
        f.puts "Average packets per timestamp: #{(audio_packets.length.to_f / rtp_timestamps.length).round(2)}"
      end

      puts "Saved #{audio_packets.length} audio packets to #{audio_dir}"
    end

    def save_discarded_packets(discarded_packets, discarded_dir)
      # Save discarded packets to separate directory for analysis

      # Create packets subdirectory
      packets_dir = File.join(discarded_dir, 'packets')
      FileUtils.mkdir_p(packets_dir)

      # Save raw binary data
      raw_file = File.join(discarded_dir, 'discarded_packets.bin')
      File.open(raw_file, 'wb') do |f|
        discarded_packets.each do |pkt_data|
          payload = pkt_data[:payload]
          f.write(payload) if payload
        end
      end

      # Save individual packet binary files
      discarded_packets.each_with_index do |pkt_data, idx|
        packet_num = idx + 1
        packet_file = File.join(packets_dir, "packet#{packet_num.to_s.rjust(6, '0')}.bin")
        File.binwrite(packet_file, pkt_data[:payload]) if pkt_data[:payload]
      end

      # Save analysis data as JSON (including discard reason)
      analysis_file = File.join(discarded_dir, 'discarded_packets.json')
      analysis_data = discarded_packets.map do |p|
        analysis = p[:analysis].dup
        analysis[:discard_reason] = p[:discard_reason]
        analysis
      end
      File.write(analysis_file, JSON.pretty_generate(analysis_data))

      # Save summary report
      summary_file = File.join(discarded_dir, 'summary.txt')
      File.open(summary_file, 'w') do |f|
        f.puts "Discarded Packets Analysis"
        f.puts "=" * 50
        f.puts "Total discarded packets: #{discarded_packets.length}"
        f.puts ""

        # Group by discard reason
        discard_reasons = {}
        discarded_packets.each do |pkt_data|
          reason = pkt_data[:discard_reason] || "Unknown"
          discard_reasons[reason] ||= 0
          discard_reasons[reason] += 1
        end

        if discard_reasons.length > 0
          f.puts "Discard Reasons:"
          discard_reasons.sort.each do |reason, count|
            f.puts "  #{reason}: #{count}"
          end
        else
          f.puts "No packets discarded - stream is clean!"
        end
      end

      puts "Saved #{discarded_packets.length} discarded packets to #{discarded_dir}"
    end

    def extract_sps_pps(h264_data)
      # Extract SPS and PPS NAL units from H.264 data
      sps_pps = ''
      i = 0

      while i < h264_data.length - 4
        if h264_data[i..i+3] == "\x00\x00\x00\x01"
          nal_header = h264_data[i+4].ord
          nal_type = nal_header & 0x1F

          # Find the next start code
          next_start = i + 4
          while next_start < h264_data.length - 4
            if h264_data[next_start..next_start+3] == "\x00\x00\x00\x01"
              break
            end
            next_start += 1
          end

          # Extract this NAL unit
          nal_unit = h264_data[i..next_start-1]

          # Keep SPS (7) and PPS (8)
          if nal_type == 7 || nal_type == 8
            sps_pps += nal_unit
          end

          i = next_start
        else
          i += 1
        end
      end

      sps_pps
    end

    def calculate_frame_rate(rtp_timestamps, capture_duration)
      # Calculate actual frame rate from RTP timestamps
      # RTP clock rate for H.264 is 90000 Hz

      return 25.0 if rtp_timestamps.length < 2 || capture_duration <= 0

      # Number of frames is the number of unique RTP timestamps
      num_frames = rtp_timestamps.length

      # Frame rate = number of frames / capture duration
      frame_rate = num_frames / capture_duration.to_f

      # Clamp to reasonable values (5-60 fps)
      frame_rate = [frame_rate, 5.0].max
      frame_rate = [frame_rate, 60.0].min

      puts "Calculated frame rate: #{frame_rate.round(2)} fps (#{num_frames} frames in #{capture_duration}s)"

      frame_rate
    end

    def defragment_h264_stream(packets_data)
      # De-fragment H.264 NAL units from all packets in order
      # Skip packets until we find SPS to ensure proper stream structure
      # Skip duplicate SPS/PPS that appear after the first occurrence

      result = ''
      current_nal = nil
      found_sps = false
      found_pps = false
      skipped_count = 0
      added_count = 0

      packets_data.each_with_index do |pkt_data, idx|
        payload = pkt_data[:payload]
        if !payload || payload.length < 1
          skipped_count += 1
          next
        end

        first_byte = payload[0].ord
        nal_unit_type = first_byte & 0x1F

        # Skip packets until we find SPS (NAL type 7)
        if !found_sps && nal_unit_type != 7
          skipped_count += 1
          next
        end
        found_sps = true

        # Skip duplicate SPS/PPS after the first occurrence
        if found_pps && (nal_unit_type == 7 || nal_unit_type == 8)
          # This is a duplicate SPS or PPS, skip it
          skipped_count += 1
          next
        end

        # Mark that we've seen PPS (which comes after SPS)
        if nal_unit_type == 8
          found_pps = true
        end

        # Skip reserved NAL types (30-31)
        if nal_unit_type >= 30
          skipped_count += 1
          next
        end

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
            skipped_count += 1
            next
          end

          if start_bit == 1
            # Start of fragmented NAL unit
            # Create NAL unit header with the original NAL type
            nri = (first_byte >> 5) & 0x3
            nal_header = ((nri << 5) | nal_type).chr
            current_nal = "\x00\x00\x01" + nal_header + fragment_data
          elsif current_nal && fragment_data
            # Continuation of fragmented NAL unit
            current_nal += fragment_data
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

    def defragment_h264_frame(frame_packets, is_first_frame = true)
      # De-fragment H.264 NAL units from RTP packets
      # Handle FU-A (Fragmentation Unit A) and single NAL units

      result = ''
      current_nal = nil

      frame_packets.each do |pkt_data|
        payload = pkt_data[:payload]
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
            # Create NAL unit header with the original NAL type
            nri = (first_byte >> 5) & 0x3
            nal_header = ((nri << 5) | nal_type).chr
            current_nal = "\x00\x00\x01" + nal_header + fragment_data
          elsif current_nal && fragment_data
            # Continuation of fragmented NAL unit
            current_nal += fragment_data
          elsif !current_nal && start_bit == 0
            # Orphaned fragment (continuation without start) - skip it
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

    def generate_mp4_from_h264_stream(h264_stream, output_dir, fps = 25.0)
      mp4_file = File.join(output_dir, 'stream.mp4')

      # Return if MP4 already exists
      return if File.exist?(mp4_file)

      begin
        # Save H.264 stream to file
        h264_file = File.join(output_dir, 'stream.h264')
        File.binwrite(h264_file, h264_stream)

        puts "Created H.264 file: #{h264_file} (#{File.size(h264_file)} bytes)"

        # Use ffmpeg to copy H.264 stream to MP4 container with proper timing
        # -r fps sets the input frame rate
        # -c:v copy copies the H.264 stream without re-encoding
        # -movflags +faststart puts moov atom at the beginning for streaming
        cmd = "ffmpeg -r #{fps} -f h264 -i #{h264_file} -c:v copy -movflags +faststart -y #{mp4_file} 2>&1"
        output = `#{cmd}`

        if File.exist?(mp4_file) && File.size(mp4_file) > 10000
          puts "Created MP4 file with ffmpeg: #{mp4_file} (#{File.size(mp4_file)} bytes) at #{fps.round(2)} fps"
        else
          puts "ffmpeg copy failed, trying with re-encoding..."

          # Fallback: re-encode with libx264
          cmd = "ffmpeg -r #{fps} -f h264 -i #{h264_file} -c:v libx264 -preset ultrafast -r #{fps} -y #{mp4_file} 2>&1"
          output = `#{cmd}`

          if File.exist?(mp4_file) && File.size(mp4_file) > 10000
            puts "Created MP4 file with re-encoding: #{mp4_file} (#{File.size(mp4_file)} bytes)"
          else
            puts "Warning: MP4 generation failed"
          end
        end
      rescue => e
        puts "Warning: Failed to generate MP4: #{e.message}"
      end
    end

    def generate_mp4_from_frames(frames_dir, output_dir, fps = 25.0)
      mp4_file = File.join(output_dir, 'stream.mp4')

      # Return if MP4 already exists
      return if File.exist?(mp4_file)

      begin
        # Create H.264 file by concatenating frames
        h264_file = File.join(output_dir, 'stream.h264')
        File.open(h264_file, 'wb') do |out|
          Dir.glob("#{frames_dir}/frame*.bin").sort.each do |frame_file|
            frame_data = File.binread(frame_file)
            # Frames already have proper H.264 structure with start codes
            out.write(frame_data)
          end
        end

        puts "Created H.264 file: #{h264_file} (#{File.size(h264_file)} bytes)"

        # Use ffmpeg to copy H.264 stream to MP4 container with proper timing
        # -r fps sets the input frame rate
        # -c:v copy copies the H.264 stream without re-encoding
        # -movflags +faststart puts moov atom at the beginning for streaming
        cmd = "ffmpeg -r #{fps} -f h264 -i #{h264_file} -c:v copy -movflags +faststart -y #{mp4_file} 2>/dev/null"
        result = system(cmd)

        if result && File.exist?(mp4_file) && File.size(mp4_file) > 10000
          puts "Created MP4 file with ffmpeg: #{mp4_file} (#{File.size(mp4_file)} bytes) at #{fps.round(2)} fps"
        else
          puts "ffmpeg copy failed, trying with re-encoding..."

          # Fallback: re-encode with libx264
          cmd = "ffmpeg -r #{fps} -f h264 -i #{h264_file} -c:v libx264 -preset ultrafast -r #{fps} -y #{mp4_file} 2>/dev/null"
          system(cmd)

          if File.exist?(mp4_file) && File.size(mp4_file) > 10000
            puts "Created MP4 file with re-encoding: #{mp4_file} (#{File.size(mp4_file)} bytes)"
          else
            puts "Warning: MP4 generation failed"
          end
        end
      rescue => e
        puts "Warning: Failed to generate MP4: #{e.message}"
      end
    end
  end
end

