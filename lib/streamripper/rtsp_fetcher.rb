require 'socket'
require 'uri'
require 'digest'

module Streamripper
  class RTSPFetcher
    attr_reader :url, :socket, :logger

    def initialize(url, logger = nil)
      @url = url
      @logger = logger || Logger.new($stdout)
      @socket = nil
      @sequence_number = 0
      @session_id = nil
      @auth_header = nil
      @nonce = nil
      @realm = nil
    end

    def connect
      uri = URI.parse(@url)
      @host = uri.host
      @port = uri.port || 554
      @path = uri.path.empty? ? '/' : uri.path

      @logger.info("Connecting to RTSP stream at #{@host}:#{@port}#{@path}")

      @socket = TCPSocket.new(@host, @port)
      @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, [5, 0].pack("l_l_"))
      @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, [5, 0].pack("l_l_"))
      @logger.info("Connected successfully")

      send_options_request
      send_describe_request
      send_setup_request
      send_play_request
    end

    def read_packet
      return nil unless @socket

      begin
        # Read RTP-over-TCP framing (RFC 2326)
        # Format: $ (1 byte) + channel (1 byte) + length (2 bytes) + data
        # Channels: 0=video RTP, 1=video RTCP, 2=audio RTP, 3=audio RTCP
        marker = @socket.read(1)
        return nil if marker.nil?

        # Check for RTP-over-TCP marker ($)
        unless marker == '$'
          @logger.debug("Skipping non-RTP data")
          return read_packet  # Try next packet
        end

        channel = @socket.read(1)
        return nil if channel.nil?
        channel_num = channel.ord

        length_bytes = @socket.read(2)
        return nil if length_bytes.nil? || length_bytes.length < 2

        packet_length = (length_bytes[0].ord << 8) | length_bytes[1].ord
        rtp_packet = @socket.read(packet_length)
        return nil if rtp_packet.nil? || rtp_packet.length < 12

        # Check for packet alignment issue (16-byte prefix before RTP header)
        first_byte_version = (rtp_packet[0].ord >> 6) & 0x3

        # If first byte doesn't have valid RTP version, this is a malformed packet
        # Reject it entirely instead of trying to parse with offset
        if first_byte_version != 2
          @logger.debug("Skipping packet with invalid RTP version: #{first_byte_version}")
          return read_packet  # Try next packet
        end

        rtp_offset = 0

        # Parse RTP header from correct offset
        header = rtp_packet[rtp_offset..rtp_offset+11]
        version = (header[0].ord >> 6) & 0x3

        # Validate RTP version (must be 2)
        unless version == 2
          @logger.debug("Skipping packet with invalid RTP version at offset #{rtp_offset}: #{version}")
          return read_packet  # Try next packet
        end

        padding = (header[0].ord >> 5) & 0x1
        extension = (header[0].ord >> 4) & 0x1
        cc = header[0].ord & 0xf
        marker_bit = (header[1].ord >> 7) & 0x1
        pt = header[1].ord & 0x7f
        seq = (header[2].ord << 8) | header[3].ord
        timestamp = (header[4].ord << 24) | (header[5].ord << 16) |
                    (header[6].ord << 8) | header[7].ord
        ssrc = (header[8].ord << 24) | (header[9].ord << 16) |
               (header[10].ord << 8) | header[11].ord

        # Calculate payload offset (after RTP header and CSRC list)
        payload_offset = rtp_offset + 12 + (cc * 4)

        # Skip extension header if present
        if extension == 1
          ext_header_offset = payload_offset
          if rtp_packet.length >= ext_header_offset + 4
            ext_length = ((rtp_packet[ext_header_offset + 2].ord << 8) | rtp_packet[ext_header_offset + 3].ord) * 4
            payload_offset = ext_header_offset + 4 + ext_length
          end
        end

        # Extract payload
        payload = rtp_packet[payload_offset..-1] || ''

        # Note: csrc_data and ext_data are already handled in payload extraction
        csrc_data = nil
        ext_data = nil

        {
          version: version,
          padding: padding,
          extension: extension,
          cc: cc,
          marker: marker_bit,
          payload_type: pt,
          sequence_number: seq,
          timestamp: timestamp,
          ssrc: ssrc,
          csrc_data: csrc_data,
          extension_data: ext_data,
          payload: payload,
          raw_header: header,
          raw_packet: rtp_packet,  # Complete RTP packet data
          rtsp_channel: channel_num,  # Include RTSP channel for raw file
          wallclock_time: Time.now.to_f # seconds with microsecond precision
        }
      rescue EOFError, Errno::ECONNRESET => e
        @logger.error("Connection error: #{e.message}")
        close
        nil
      end
    end

    def fetch
      connect

      begin
        loop do
          packet = read_packet
          break if packet.nil?
          yield packet if block_given?
        end
      ensure
        close
      end
    end

    def close
      @socket.close if @socket
      @socket = nil
      @logger.info("Connection closed")
    end

    private

    def send_options_request
      @sequence_number += 1
      request = "OPTIONS #{@url} RTSP/1.0\r\n"
      request += "CSeq: #{@sequence_number}\r\n"
      request += "User-Agent: Streamripper/0.1.0\r\n"
      request += "\r\n"
      
      @socket.write(request)
      response = read_response
      @logger.debug("OPTIONS response: #{response}")
    end

    def send_describe_request
      @sequence_number += 1
      request = "DESCRIBE #{@url} RTSP/1.0\r\n"
      request += "CSeq: #{@sequence_number}\r\n"
      request += "Accept: application/sdp\r\n"
      request += "User-Agent: Streamripper/0.1.0\r\n"

      # Add auth if we have credentials
      uri = URI.parse(@url)
      if uri.user && uri.password
        if @nonce && @realm
          request += build_digest_auth(uri.user, uri.password, "DESCRIBE", @url)
        end
      end

      request += "\r\n"

      @socket.write(request)
      response = read_response
      @logger.debug("DESCRIBE response: #{response}")

      # Extract auth challenge if 401
      if response =~ /WWW-Authenticate: Digest realm="([^"]+)".*nonce="([^"]+)"/
        @realm = $1
        @nonce = $2
        # Retry with auth
        if uri.user && uri.password
          send_describe_request
        end
      end
    end

    def send_setup_request
      @sequence_number += 1
      # Use TCP interleaved transport for RTP-over-TCP
      # Setup video track (track1)
      setup_url = @url.end_with?('/') ? "#{@url}track1" : "#{@url}/track1"
      request = "SETUP #{setup_url} RTSP/1.0\r\n"
      request += "CSeq: #{@sequence_number}\r\n"
      request += "Transport: RTP/AVP/TCP;unicast;interleaved=0-1\r\n"
      request += "User-Agent: Streamripper/0.1.0\r\n"

      # Add auth if available
      uri = URI.parse(@url)
      if uri.user && uri.password && @nonce && @realm
        request += build_digest_auth(uri.user, uri.password, "SETUP", setup_url)
      end

      request += "\r\n"

      @socket.write(request)
      response = read_response
      @logger.debug("SETUP response: #{response}")

      # Extract session ID from response
      if response =~ /Session: ([^\r\n;]+)/
        @session_id = $1.strip
      end
    end

    def send_play_request
      @sequence_number += 1
      request = "PLAY #{@url} RTSP/1.0\r\n"
      request += "CSeq: #{@sequence_number}\r\n"
      request += "Session: #{@session_id}\r\n" if @session_id
      request += "Range: npt=0.000-\r\n"
      request += "User-Agent: Streamripper/0.1.0\r\n"

      # Add auth if available
      uri = URI.parse(@url)
      if uri.user && uri.password && @nonce && @realm
        request += build_digest_auth(uri.user, uri.password, "PLAY", @url)
      end

      request += "\r\n"

      @socket.write(request)
      response = read_response
      @logger.debug("PLAY response: #{response}")
    end

    def read_response
      response = ""
      content_length = 0

      while true
        line = @socket.gets
        break if line.nil?
        response += line

        # Extract content length if present
        if line =~ /Content-Length: (\d+)/
          content_length = $1.to_i
        end

        # End of headers
        break if line == "\r\n"
      end

      # Read body if content-length specified
      if content_length > 0
        body = @socket.read(content_length)
        response += body if body
      end

      response
    end

    def build_digest_auth(username, password, method, uri)
      return "" unless @nonce && @realm

      ha1 = Digest::MD5.hexdigest("#{username}:#{@realm}:#{password}")
      ha2 = Digest::MD5.hexdigest("#{method}:#{uri}")
      response_hash = Digest::MD5.hexdigest("#{ha1}:#{@nonce}:#{ha2}")

      auth = "Authorization: Digest username=\"#{username}\", "
      auth += "realm=\"#{@realm}\", "
      auth += "nonce=\"#{@nonce}\", "
      auth += "uri=\"#{uri}\", "
      auth += "response=\"#{response_hash}\"\r\n"
      auth
    end
  end
end

