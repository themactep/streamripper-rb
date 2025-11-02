require 'thor'
require 'fileutils'
require_relative 'output_manager'
require_relative 'report_generator'
require_relative 'packet_extractor'
require_relative 'web_server'
require_relative 'raw_stream_reparser'

module Streamripper
  class CLI < Thor
    desc 'capture URL [OPTIONS]', 'Capture and analyze RTSP stream from IP camera'
    option :format, aliases: '-f', default: 'json', enum: ['json', 'csv', 'both'],
           desc: 'Log format (json, csv, or both)'
    option :duration, aliases: '-d', type: :numeric, default: 0,
           desc: 'Duration to capture in seconds (0 = infinite)'
    option :verbose, aliases: '-v', type: :boolean, default: false,
           desc: 'Enable verbose logging'
    option :max_packets, aliases: '-m', type: :numeric, default: 0,
           desc: 'Maximum number of packets to capture (0 = infinite)'

    desc 'reparse SCAN_DIR', 'Re-parse raw_stream.bin with new filtering'
    def reparse(scan_dir)
      setup_logging

      puts "Streamripper v#{Streamripper::VERSION}"
      puts "=" * 60
      puts "Re-parsing Raw Stream"
      puts "=" * 60
      puts ""

      reparser = RawStreamReparser.new(scan_dir)
      reparser.reparse
    end

    desc 'web [OPTIONS]', 'Start web UI server'
    option :port, aliases: '-p', type: :numeric, default: 8080,
           desc: 'Port to run web server on'
    option :verbose, aliases: '-v', type: :boolean, default: false,
           desc: 'Enable verbose logging'

    def web
      setup_logging

      puts "Streamripper v#{Streamripper::VERSION}"
      puts "=" * 60
      puts "Web UI Server"
      puts "=" * 60

      server = WebServer.new(options[:port])
      server.start
    end

    desc 'capture URL [OPTIONS]', 'Capture and analyze RTSP stream from IP camera'
    option :format, aliases: '-f', default: 'json', enum: ['json', 'csv', 'both'],
           desc: 'Log format (json, csv, or both)'
    option :duration, aliases: '-d', type: :numeric, default: 0,
           desc: 'Duration to capture in seconds (0 = infinite)'
    option :verbose, aliases: '-v', type: :boolean, default: false,
           desc: 'Enable verbose logging'
    option :max_packets, aliases: '-m', type: :numeric, default: 0,
           desc: 'Maximum number of packets to capture (0 = infinite)'

    def capture(url)
      setup_logging

      # Initialize output manager
      output_mgr = OutputManager.new(url)

      puts "Streamripper v#{Streamripper::VERSION}"
      puts "=" * 60
      puts "RTSP Stream Analyzer"
      puts "=" * 60
      puts "URL: #{url}"
      puts "Stream Directory: #{output_mgr.stream_dir}"
      puts "Run Directory: #{output_mgr.run_dir}"
      puts "Format: #{options[:format]}"
      puts "Duration: #{options[:duration] > 0 ? "#{options[:duration]}s" : 'infinite'}"
      puts "Max Packets: #{options[:max_packets] > 0 ? options[:max_packets] : 'infinite'}"
      puts "=" * 60
      puts

      begin
        run_capture(url, output_mgr)
      rescue Interrupt
        puts "\n\nCapture interrupted by user"
        exit 0
      rescue StandardError => e
        puts "Error: #{e.message}"
        puts e.backtrace if options[:verbose]
        exit 1
      end
    end

    private

    def setup_logging
      @logger = Logger.new($stdout)
      @logger.level = options[:verbose] ? Logger::DEBUG : Logger::INFO
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S.%3N')}] #{severity}: #{msg}\n"
      end
    end

    def run_capture(url, output_mgr)
      # Initialize components
      fetcher = RTSPFetcher.new(url, @logger)
      analyzer = PacketAnalyzer.new

      # Generate output filenames
      analysis_file = output_mgr.get_output_path("analysis.#{options[:format] == 'both' ? 'json' : options[:format]}")
      raw_stream_file = output_mgr.get_output_path("raw_stream.bin")
      packets_dir = File.join(output_mgr.run_dir, 'packets')
      FileUtils.mkdir_p(packets_dir)

      logger = PacketLogger.new(analysis_file, options[:format].to_sym)
      saver = StreamSaver.new(raw_stream_file)

      # Connect to stream
      fetcher.connect

      start_time = Time.now
      packet_count = 0

      puts "Capturing packets..."
      puts

      begin
        loop do
          # Check duration limit
          if options[:duration] > 0
            elapsed = Time.now - start_time
            if elapsed > options[:duration]
              puts "\nDuration limit reached (#{options[:duration]}s)"
              break
            end
          end

          # Check packet count limit
          if options[:max_packets] > 0 && packet_count >= options[:max_packets]
            puts "\nPacket limit reached (#{options[:max_packets]} packets)"
            break
          end

          # Read and process packet
          packet = fetcher.read_packet
          break if packet.nil?

          # Analyze packet
          analysis = analyzer.analyze(packet)

          # Log analysis
          logger.log_packet(analysis)

          # Save raw stream
          saver.save_packet(packet)

          packet_count += 1

          # Save individual packet binary file (numbered from 1)
          packet_file = File.join(packets_dir, "packet#{packet_count.to_s.rjust(6, '0')}.bin")
          File.binwrite(packet_file, packet[:raw_packet])

          # Print progress every 100 packets
          if packet_count % 100 == 0
            elapsed = Time.now - start_time
            rate = packet_count / elapsed
            puts "Captured #{packet_count} packets (#{rate.round(2)} pkt/s)"
          end
        end
      ensure
        # Cleanup
        fetcher.close
        logger.close
        saver.close
        puts "Saved #{packet_count} individual packets to packets/ directory"
      end

      # Extract unknown/interesting packets and frames
      extractor = PacketExtractor.new(output_mgr.run_dir)
      unknown_packets = extract_unknown_packets(analyzer, extractor)
      frame_files = extract_frames(analyzer, extractor)

      # Generate HTML report if JSON was created
      analysis_json = output_mgr.get_output_path("analysis.json")
      if File.exist?(analysis_json)
        report_gen = ReportGenerator.new(analysis_json, extractor.frames_dir)
        report_path = report_gen.generate
      end

      # Print summary
      print_summary(analyzer, logger, saver, packet_count, Time.now - start_time, output_mgr, report_path, unknown_packets, frame_files.length)
    end

    def print_summary(analyzer, logger, saver, packet_count, duration, output_mgr, report_path = nil, unknown_packets = [], frame_count = 0)
      puts
      puts "=" * 60
      puts "CAPTURE SUMMARY"
      puts "=" * 60
      puts "Total Packets Captured: #{packet_count}"
      puts "Duration: #{duration.round(2)}s"
      puts "Packet Rate: #{(packet_count / duration).round(2)} pkt/s"
      puts
      puts "Analysis Log:"
      puts "  Directory: #{output_mgr.run_dir}"
      puts "  Format: #{options[:format]}"
      if report_path
        puts "  Report: #{report_path}"
      end
      puts
      puts "Extracted Data:"
      puts "  Frames: #{frame_count}"
      if unknown_packets.length > 0
        puts "  Unknown Packets: #{unknown_packets.length}"
      end
      puts
      puts "Raw Stream:"
      puts "  Size: #{saver.bytes_written} bytes"

      if unknown_packets.length > 0
        puts
        puts "Unknown Packets:"
        unknown_packets.each do |pkt|
          puts "  - packet#{pkt[:packet_number].to_s.rjust(5, '0')}.bin (#{pkt[:packet_type]})"
        end
      end

      puts "=" * 60
    end

    def extract_frames(analyzer, extractor)
      # Group packets by RTP timestamp to create frames, preserving order
      frames_by_rtp = {}
      frame_order = []

      analyzer.packets_data.each do |pkt_data|
        rtp_ts = pkt_data[:analysis][:rtp_timestamp_raw]
        unless frames_by_rtp.key?(rtp_ts)
          frames_by_rtp[rtp_ts] = []
          frame_order << rtp_ts
        end
        frames_by_rtp[rtp_ts] << pkt_data
      end

      # Save each frame in order
      frame_files = []
      frame_number = 1
      frame_order.each do |rtp_ts|
        packets = frames_by_rtp[rtp_ts]
        frame_info = extractor.save_frame(frame_number, packets)
        frame_files << frame_info
        frame_number += 1
      end

      frame_files
    end

    def extract_unknown_packets(analyzer, extractor)
      unknown = []
      analyzer.packets_data.each do |pkt_data|
        packet_type = pkt_data[:analysis][:packet_type]
        # Check if packet type is unknown (either exactly 'Unknown' or 'Unknown(code)')
        if packet_type && (packet_type == 'Unknown' || packet_type.to_s.start_with?('Unknown('))
          extractor.save_packet(pkt_data[:packet_number], pkt_data[:payload])
          unknown << {
            packet_number: pkt_data[:packet_number],
            payload_type_code: pkt_data[:payload_type_code],
            packet_type: packet_type
          }
        end
      end
      unknown
    end
  end
end

