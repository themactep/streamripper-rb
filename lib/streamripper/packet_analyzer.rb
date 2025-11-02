module Streamripper
  class PacketAnalyzer
    PAYLOAD_TYPES = {
      0 => 'PCMU',
      1 => 'Reserved',
      2 => 'Reserved',
      3 => 'GSM',
      4 => 'G723',
      5 => 'DVI4',
      6 => 'DVI4',
      7 => 'LPC',
      8 => 'PCMA',
      9 => 'G722',
      10 => 'L16',
      11 => 'L16',
      12 => 'QCELP',
      13 => 'CN',
      14 => 'MPA',
      15 => 'G728',
      16 => 'DVI4',
      17 => 'DVI4',
      18 => 'G729',
      19 => 'Reserved',
      20 => 'Unassigned',
      26 => 'JPEG',
      28 => 'nv',
      31 => 'H261',
      32 => 'MPV',
      33 => 'MP2T',
      34 => 'H263',
      72 => 'PCM-Mu-Law',  # Dynamic payload type for PCM Mu-Law
      96 => 'H264',
      97 => 'H265',
      189 => 'H264-Dynamic'  # Dynamic payload type for H.264
    }.freeze

    # H.264 NAL unit types
    H264_NAL_TYPES = {
      0 => 'Unspecified',
      1 => 'Coded slice of a non-IDR picture',
      2 => 'Coded slice data partition A',
      3 => 'Coded slice data partition B',
      4 => 'Coded slice data partition C',
      5 => 'Coded slice of an IDR picture',
      6 => 'Supplemental enhancement information (SEI)',
      7 => 'Sequence parameter set (SPS)',
      8 => 'Picture parameter set (PPS)',
      9 => 'Access unit delimiter',
      10 => 'End of sequence',
      11 => 'End of stream',
      12 => 'Filler data',
      13 => 'Sequence parameter set extension',
      14 => 'Prefix NAL unit',
      15 => 'Subset sequence parameter set',
      19 => 'Coded slice of an auxiliary coded picture without partitioning',
      20 => 'Coded slice extension'
    }.freeze

    # RTP clock rates (Hz) for different payload types
    RTP_CLOCK_RATES = {
      0 => 8000,    # PCMU
      3 => 8000,    # GSM
      4 => 8000,    # G723
      5 => 8000,    # DVI4
      6 => 16000,   # DVI4
      7 => 8000,    # LPC
      8 => 8000,    # PCMA
      9 => 8000,    # G722
      10 => 44100,  # L16
      11 => 44100,  # L16
      12 => 8000,   # QCELP
      14 => 90000,  # MPA
      15 => 8000,   # G728
      26 => 90000,  # JPEG
      28 => 90000,  # nv
      31 => 90000,  # H261
      32 => 90000,  # MPV
      33 => 90000,  # MP2T
      34 => 90000,  # H263
      72 => 8000,   # PCM-Mu-Law
      96 => 90000,  # H264
      97 => 90000,  # H265
      189 => 90000  # H264-Dynamic
    }.freeze

    attr_reader :packet_count, :last_timestamp, :timestamp_deviations, :packets_data

    def initialize
      @packet_count = 0
      @last_timestamp = nil
      @baseline_rtp_timestamp = nil
      @baseline_wallclock_us = nil
      @rtp_clock_hz = 90000  # H.264 uses 90kHz clock
      @last_payload_type = nil
      @last_fragment_timestamp = nil
      @fragment_counter = 0
      @current_frame_timestamp = nil
      @frame_start_packet_number = nil
      @packets_data = []  # Store packet data for extraction
    end

    def analyze(packet)
      @packet_count += 1

      payload_type_name = get_payload_type_name(packet[:payload_type])
      frame_type = detect_frame_type(packet, packet[:payload_type], packet[:timestamp])

      # Convert RTP timestamp to microseconds based on clock rate
      clock_rate = RTP_CLOCK_RATES[packet[:payload_type]] || 90000
      rtp_timestamp_us = (packet[:timestamp].to_f / clock_rate * 1_000_000).to_i

      # Track fragment numbers and parent packet
      if packet[:timestamp] != @current_frame_timestamp
        # New frame started
        @current_frame_timestamp = packet[:timestamp]
        @fragment_counter = 1
        @frame_start_packet_number = @packet_count
      else
        # Continuation of same frame
        @fragment_counter += 1
      end

      # Add fragment info to frame_type
      display_frame_type = frame_type
      if frame_type == 'Fragment'
        # Continuation fragment - show parent packet number and fragment index
        display_frame_type = "Fragment(#{@frame_start_packet_number},#{@fragment_counter})"
      elsif frame_type.include?('-')
        # First fragment of a frame (I-frame, P-frame, SPS, PPS, etc.)
        display_frame_type = frame_type
      end

      wallclock_time_us = (packet[:wallclock_time] * 1_000_000).to_i

      # Extract NAL unit type for baseline detection
      nal_unit_type = nil
      if packet[:payload] && packet[:payload].length > 0
        first_byte = packet[:payload][0].ord
        nal_unit_type = first_byte & 0x1F
      end

      analysis = {
        packet_number: @packet_count,
        wallclock_time_us: wallclock_time_us,
        packet_type: payload_type_name,
        frame_type: display_frame_type,
        payload_type_code: packet[:payload_type],
        raw_packet_size: calculate_packet_size(packet),
        rtp_timestamp_raw: packet[:timestamp],
        rtp_timestamp_us: rtp_timestamp_us,
        sequence_number: packet[:sequence_number],
        marker_bit: packet[:marker],
        ssrc: packet[:ssrc],
        timestamp_deviation_us: calculate_timestamp_deviation(packet[:timestamp], wallclock_time_us, nal_unit_type)
      }

      # Store packet data for extraction
      @packets_data << {
        packet_number: @packet_count,
        payload_type_code: packet[:payload_type],
        payload: packet[:payload],
        analysis: analysis
      }

      analysis
    end

    private

    def get_payload_type_name(pt)
      PAYLOAD_TYPES[pt] || "Unknown(#{pt})"
    end

    def calculate_packet_size(packet)
      size = 12 # RTP header
      size += (packet[:cc] * 4) if packet[:cc] > 0
      size += 4 + packet[:extension_data].length if packet[:extension_data]
      size += packet[:payload].length if packet[:payload]
      size
    end

    def calculate_timestamp_deviation(timestamp, wallclock_us, nal_unit_type = nil)
      # If timestamp hasn't changed (same frame, fragmented packets), deviation is 0
      if @last_timestamp == timestamp
        return 0
      end

      # Establish baseline on first SPS packet (start of valid stream)
      if @baseline_rtp_timestamp.nil?
        # Only set baseline when we see an SPS (NAL type 7)
        if nal_unit_type == 7
          @baseline_rtp_timestamp = timestamp
          @baseline_wallclock_us = wallclock_us
          @last_timestamp = timestamp
          return 0
        else
          # Before first SPS, return 0 deviation (no baseline yet)
          @last_timestamp = timestamp
          return 0
        end
      end

      # Calculate expected wallclock time based on RTP timestamp
      # RTP time elapsed since baseline
      rtp_time_elapsed = timestamp - @baseline_rtp_timestamp

      # Handle 32-bit RTP timestamp wraparound
      if rtp_time_elapsed < -2147483648  # Less than -2^31, likely a wraparound
        rtp_time_elapsed = rtp_time_elapsed + 4294967296  # Add 2^32 to unwrap
      end

      # Convert RTP time to microseconds
      rtp_time_us = (rtp_time_elapsed * 1_000_000) / @rtp_clock_hz

      # Expected wallclock time if stream was perfectly synchronized
      expected_wallclock_us = @baseline_wallclock_us + rtp_time_us

      # Actual deviation: difference between expected and actual wallclock
      deviation = wallclock_us - expected_wallclock_us

      @last_timestamp = timestamp

      deviation
    end

    def average_timestamp_deviation
      return 0 if @timestamp_deviations.empty?
      @timestamp_deviations.sum.to_f / @timestamp_deviations.length
    end

    def max_timestamp_deviation
      @timestamp_deviations.max || 0
    end

    def min_timestamp_deviation
      @timestamp_deviations.min || 0
    end

    def get_statistics
      {
        total_packets: @packet_count,
        average_deviation: average_timestamp_deviation,
        max_deviation: max_timestamp_deviation,
        min_deviation: min_timestamp_deviation
      }
    end

    def detect_frame_type(packet, payload_type, rtp_timestamp = nil)
      return 'Unknown' unless packet[:payload] && packet[:payload].length > 0

      case payload_type
      when 96, 189  # H264 (96 = static, 189 = dynamic)
        detect_h264_frame_type(packet[:payload], rtp_timestamp)
      when 97  # H265
        detect_h265_frame_type(packet[:payload])
      when 26  # JPEG
        'JPEG'
      when 0    # PCMU
        'Audio'
      when 3    # GSM
        'Audio'
      when 4    # G723
        'Audio'
      when 8    # PCMA
        'Audio'
      when 9    # G722
        'Audio'
      when 12   # QCELP
        'Audio'
      when 14   # MPA
        'Audio'
      when 15   # G728
        'Audio'
      when 18   # G729
        'Audio'
      when 72   # PCM-Mu-Law
        'Audio'
      when 97   # MPEG4-GENERIC (often audio)
        'Audio'
      else
        # Check if it's an audio codec by payload type name
        codec_name = get_payload_type_name(payload_type)
        if codec_name.include?('Audio') || codec_name.include?('audio') || codec_name.include?('PCM')
          'Audio'
        else
          'Unknown'
        end
      end
    end

    def detect_h264_frame_type(payload, rtp_timestamp)
      return 'Unknown' if payload.length < 2

      # H.264 RTP payload format (RFC 3984)
      first_byte = payload[0].ord
      nal_unit_type = first_byte & 0x1F

      # Check for fragmented NAL units (FU-A or FU-B)
      if nal_unit_type == 28  # FU-A (Fragmentation Unit A)
        return detect_fu_a(payload, rtp_timestamp)
      elsif nal_unit_type == 29  # FU-B (Fragmentation Unit B)
        return detect_fu_b(payload, rtp_timestamp)
      elsif nal_unit_type == 24  # STAP-A (Single-Time Aggregation Packet)
        return 'STAP-A'
      elsif nal_unit_type == 25  # STAP-B
        return 'STAP-B'
      elsif nal_unit_type == 26  # MTAP16
        return 'MTAP16'
      elsif nal_unit_type == 27  # MTAP24
        return 'MTAP24'
      else
        # Single NAL unit
        return get_h264_nal_description(nal_unit_type)
      end
    end

    def detect_fu_a(payload, rtp_timestamp)
      return 'Fragment' if payload.length < 2

      fu_header = payload[1].ord
      nal_type = fu_header & 0x1F
      start_bit = (fu_header >> 7) & 0x1
      end_bit = (fu_header >> 6) & 0x1

      if start_bit == 1
        @last_fragment_timestamp = rtp_timestamp
        return get_h264_nal_description(nal_type)
      else
        return 'Fragment'
      end
    end

    def detect_fu_b(payload, rtp_timestamp)
      return 'Fragment' if payload.length < 3

      fu_header = payload[1].ord
      nal_type = fu_header & 0x1F
      start_bit = (fu_header >> 7) & 0x1
      end_bit = (fu_header >> 6) & 0x1

      if start_bit == 1
        @last_fragment_timestamp = rtp_timestamp
        return get_h264_nal_description(nal_type)
      else
        return 'Fragment'
      end
    end

    def get_h264_nal_description(nal_type)
      case nal_type
      when 0
        'Unspecified'
      when 1
        'P-frame'
      when 2
        'Slice-PartA'
      when 3
        'Slice-PartB'
      when 4
        'Slice-PartC'
      when 5
        'I-frame'
      when 6
        'SEI'
      when 7
        'SPS'
      when 8
        'PPS'
      when 9
        'AUD'
      when 10
        'End-Seq'
      when 11
        'End-Stream'
      when 12
        'Filler'
      when 13
        'SPS-Ext'
      when 14
        'Prefix-NAL'
      when 15
        'Subset-SPS'
      when 19
        'Aux-Slice'
      when 20
        'Slice-Ext'
      else
        H264_NAL_TYPES[nal_type] || "NAL-#{nal_type}"
      end
    end

    def detect_h265_frame_type(payload)
      return 'Unknown' if payload.length < 3

      # H.265 RTP payload format (RFC 7798)
      first_byte = payload[0].ord
      nal_unit_type = (first_byte >> 1) & 0x3F

      case nal_unit_type
      when 0..1
        'B-frame'
      when 2..4
        'P-frame'
      when 5..7
        'I-frame'
      when 32
        'VPS'
      when 33
        'SPS'
      when 34
        'PPS'
      when 35
        'AUD'
      when 39
        'SEI'
      else
        "H265-NAL-#{nal_unit_type}"
      end
    end

  end
end

