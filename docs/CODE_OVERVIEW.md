# Streamripper - Code Overview

## Architecture

```
bin/streamripper (entry point)
    ↓
lib/streamripper.rb (module loader)
    ├── RTSPFetcher (RTSP protocol + RTP parsing)
    ├── PacketAnalyzer (packet metadata extraction)
    ├── PacketLogger (JSON/CSV output)
    ├── StreamSaver (binary stream output)
    └── CLI (command-line interface)
```

## Core Modules

### RTSPFetcher (lib/streamripper/rtsp_fetcher.rb)

**Responsibility**: Connect to RTSP camera and read RTP packets

**Key Methods**:
- `connect()` - Establish RTSP connection and handshake
- `read_packet()` - Read and parse next RTP packet
- `close()` - Close connection

**RTSP Handshake**:
1. OPTIONS - Check server capabilities
2. DESCRIBE - Get stream description (SDP)
3. SETUP - Configure transport (RTP/AVP/TCP with interleaved)
4. PLAY - Start streaming

**RTP-over-TCP Framing** (RFC 2326):
```
$ (1 byte) + channel (1 byte) + length (2 bytes) + RTP packet
```

**RTP Header Parsing**:
- Version (2 bits)
- Padding (1 bit)
- Extension (1 bit)
- CSRC count (4 bits)
- Marker (1 bit)
- Payload type (7 bits)
- Sequence number (16 bits)
- Timestamp (32 bits)
- SSRC (32 bits)
- Optional: CSRC list, extension header

### PacketAnalyzer (lib/streamripper/packet_analyzer.rb)

**Responsibility**: Extract metadata from packets and calculate metrics

**Key Methods**:
- `analyze(packet)` - Analyze single packet
- `calculate_timestamp_deviation(timestamp)` - Calculate jitter

**Payload Type Mapping**:
- 96: H264
- 97: H265
- 26: JPEG
- 0: PCMU
- And 20+ more standard types

**Timestamp Deviation Calculation**:
```
deviation = actual_increment - expected_increment
```
- First packet: deviation = 0
- Second packet: establish expected increment
- Subsequent packets: compare to expected

**Output Fields**:
```ruby
{
  packet_number: Integer,
  wallclock_time_ms: Integer,
  packet_type: String,
  payload_type_code: Integer,
  raw_packet_size: Integer,
  stream_timestamp: Integer,
  sequence_number: Integer,
  marker_bit: Integer (0 or 1),
  ssrc: Integer,
  timestamp_deviation_ms: Integer
}
```

### PacketLogger (lib/streamripper/packet_logger.rb)

**Responsibility**: Log packet analysis in JSON/CSV formats

**Key Methods**:
- `log_packet(analysis)` - Log analyzed packet
- `close()` - Finalize and close files

**Formats**:
- **JSON**: Array of packet objects
  ```json
  [
    { packet_number: 1, ... },
    { packet_number: 2, ... }
  ]
  ```
- **CSV**: Tab-separated values with headers
- **Both**: Creates separate .json and .csv files

**File Handling**:
- JSON: Writes opening `[`, comma-separated objects, closing `]`
- CSV: Writes header row, then data rows
- Dual: Manages two separate file handles

### StreamSaver (lib/streamripper/stream_saver.rb)

**Responsibility**: Save raw RTP packets for forensic analysis

**Key Methods**:
- `save_packet(packet)` - Save raw packet data
- `close()` - Close output file

**Output Format**:
- Binary file containing complete RTP packets
- Preserves: header + CSRC + extension + payload
- Can be analyzed with Wireshark, tcpdump, etc.

### CLI (lib/streamripper/cli.rb)

**Responsibility**: Command-line interface and orchestration

**Key Methods**:
- `capture(url)` - Main capture command
- `run_capture(url)` - Orchestrate capture pipeline
- `print_summary()` - Print statistics

**Command Options**:
```
--output, -o FILE              Output file for analysis
--raw-stream, -r FILE          Output file for raw stream
--format, -f FORMAT            Output format (json/csv/both)
--duration, -d SECONDS         Capture duration (0 = infinite)
--max-packets, -m COUNT        Maximum packets (0 = infinite)
--verbose, -v                  Enable verbose logging
```

**Capture Pipeline**:
1. Initialize components (fetcher, analyzer, logger, saver)
2. Connect to RTSP stream
3. Loop:
   - Read packet from stream
   - Analyze packet
   - Log analysis
   - Save raw packet
   - Check limits (duration, packet count)
4. Cleanup and print summary

## Data Flow

```
RTSP Camera
    ↓
RTSPFetcher.read_packet()
    ↓ (returns packet dict)
PacketAnalyzer.analyze()
    ↓ (returns analysis dict)
    ├→ PacketLogger.log_packet() → JSON/CSV file
    └→ StreamSaver.save_packet() → Binary file
```

## Key Design Decisions

### 1. RTP-over-TCP (Interleaved)
- Uses TCP instead of UDP for reliability
- Packets framed with `$` marker
- Better for network traversal (firewalls, NAT)

### 2. Timestamp Deviation Tracking
- Detects jitter and frame drops
- Compares actual vs expected increment
- Useful for stream quality assessment

### 3. Dual Format Support
- JSON for programmatic analysis
- CSV for spreadsheet analysis
- Both formats simultaneously if needed

### 4. Raw Stream Preservation
- Complete packet preservation
- Enables forensic analysis
- Compatible with standard tools

### 5. Modular Architecture
- Each component has single responsibility
- Easy to test independently
- Easy to extend or replace

## Error Handling

**Connection Errors**:
- EOFError: Stream ended
- Errno::ECONNRESET: Connection reset
- Handled gracefully with logging

**File I/O Errors**:
- Directory creation: `FileUtils.mkdir_p`
- File operations: Wrapped in begin/rescue
- Cleanup in ensure blocks

**Input Validation**:
- URL parsing with URI
- Payload type validation
- Packet size validation

## Testing

**Unit Tests** (spec/):
- PacketAnalyzer: Payload type mapping, timestamp deviation
- PacketLogger: JSON/CSV formatting, file I/O
- StreamSaver: Binary output, directory creation

**Integration Tests** (test_*.rb):
- test_syntax.rb: Module loading
- test_mock_capture.rb: Full pipeline with mock packets
- test_integration.rb: All features with various formats

## Performance Characteristics

**Memory**:
- Minimal: ~50-100MB for typical captures
- Packet-by-packet processing (no buffering)

**CPU**:
- Minimal: I/O bound
- Simple calculations (no heavy processing)

**Disk I/O**:
- Depends on packet size and format
- Typical: 500-2000 kbps bitrate

**Packet Rate**:
- Typical: 100-1000 packets/second
- Depends on camera and network

## Code Quality

**Style**:
- Consistent indentation (2 spaces)
- Clear variable names
- Comments for complex logic

**Error Handling**:
- Comprehensive exception handling
- Graceful degradation
- Informative error messages

**Testing**:
- 15+ test cases
- Unit and integration tests
- Mock data for testing without camera

**Documentation**:
- Inline comments
- Method documentation
- README and guides

## Future Enhancements

Potential improvements:
- RTMP stream support
- Real-time visualization
- Statistical analysis and reporting
- Database logging
- Web UI for monitoring
- Multi-stream capture
- Integration with Wireshark

