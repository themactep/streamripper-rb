# Streamripper - Project Summary

## Overview

Streamripper is a comprehensive Ruby CLI application for capturing, analyzing, and logging RTSP streams from IP cameras with forensic capabilities. It provides detailed packet-level analysis and raw stream capture for forensic investigation.

## Project Structure

```
streamripper-rb/
├── bin/
│   └── streamripper              # CLI executable
├── lib/
│   └── streamripper/
│       ├── cli.rb                # Command-line interface (Thor)
│       ├── rtsp_fetcher.rb       # RTSP protocol handler
│       ├── packet_analyzer.rb    # Packet parsing and analysis
│       ├── packet_logger.rb      # JSON/CSV logging
│       ├── stream_saver.rb       # Raw stream capture
│       ├── version.rb            # Version info
│       └── streamripper.rb       # Main module
├── spec/
│   ├── spec_helper.rb            # RSpec configuration
│   ├── packet_analyzer_spec.rb   # Analyzer tests
│   ├── packet_logger_spec.rb     # Logger tests
│   └── stream_saver_spec.rb      # Saver tests
├── docs/
│   ├── PACKET_ANALYSIS.md        # Detailed packet format docs
│   └── TROUBLESHOOTING.md        # Troubleshooting guide
├── examples/
│   ├── config.yml                # Configuration example
│   └── usage_examples.sh         # Usage examples
├── Gemfile                       # Ruby dependencies
├── Rakefile                      # Build tasks
├── streamripper.gemspec          # Gem specification
├── README.md                     # User documentation
├── SETUP.md                      # Installation guide
└── .gitignore                    # Git ignore rules
```

## Core Modules

### 1. RTSPFetcher (`lib/streamripper/rtsp_fetcher.rb`)
- Handles RTSP protocol communication
- Connects to IP cameras via RTSP
- Reads RTP packets from stream
- Parses RTP packet headers
- Manages RTSP handshake (OPTIONS, DESCRIBE, SETUP, PLAY)

**Key Methods**:
- `connect()` - Establish RTSP connection
- `read_packet()` - Read and parse next RTP packet
- `close()` - Close connection

### 2. PacketAnalyzer (`lib/streamripper/packet_analyzer.rb`)
- Parses RTP packet structure
- Extracts packet metadata
- Calculates timestamp deviations
- Maps payload type codes to names
- Tracks stream statistics

**Key Methods**:
- `analyze(packet)` - Analyze single packet
- `calculate_timestamp_deviation()` - Detect jitter/frame drops

**Supported Payload Types**:
- H264, H265, JPEG, H261, PCMU, G722, and more

### 3. PacketLogger (`lib/streamripper/packet_logger.rb`)
- Logs packet analysis in JSON or CSV format
- Supports both formats simultaneously
- Handles file I/O and formatting
- Tracks logging statistics

**Key Methods**:
- `log_packet(analysis)` - Log analyzed packet
- `close()` - Finalize and close log file

**Output Formats**:
- JSON: Array of packet objects
- CSV: Tab-separated values with headers

### 4. StreamSaver (`lib/streamripper/stream_saver.rb`)
- Saves raw RTP packets to binary file
- Preserves complete packet structure
- Enables forensic analysis and replay
- Tracks bytes written

**Key Methods**:
- `save_packet(packet)` - Save raw packet data
- `close()` - Close output file

### 5. CLI (`lib/streamripper/cli.rb`)
- Command-line interface using Thor framework
- Argument parsing and validation
- Orchestrates all components
- Provides progress reporting
- Generates summary statistics

**Command**: `streamripper capture <URL> [OPTIONS]`

**Options**:
- `--output, -o` - Analysis log file
- `--raw-stream, -r` - Raw stream file
- `--format, -f` - Output format (json/csv/both)
- `--duration, -d` - Capture duration (seconds)
- `--max-packets, -m` - Packet limit
- `--verbose, -v` - Verbose logging

## Logged Packet Fields

Each packet is analyzed and logged with:

1. **packet_number** - Sequential packet ID
2. **wallclock_time_ms** - System timestamp (milliseconds)
3. **packet_type** - RTP payload type name
4. **payload_type_code** - Numeric payload type
5. **raw_packet_size** - Total packet size (bytes)
6. **stream_timestamp** - RTP timestamp
7. **sequence_number** - RTP sequence number
8. **marker_bit** - RTP marker bit
9. **ssrc** - Synchronization source ID
10. **timestamp_deviation_ms** - Jitter/deviation metric

## Key Features

### Real-time Analysis
- Packet-by-packet analysis as stream is captured
- Live progress reporting
- Performance metrics (packet rate, bitrate)

### Multiple Output Formats
- JSON for programmatic analysis
- CSV for spreadsheet analysis
- Both formats simultaneously

### Forensic Capabilities
- Raw stream capture for replay
- Complete packet preservation
- Timestamp deviation tracking
- Sequence number analysis

### Flexible Configuration
- Command-line options for all parameters
- Support for authentication
- Configurable output paths
- Duration and packet limits

### Comprehensive Logging
- Wallclock timestamps for correlation
- Stream timestamps for jitter analysis
- Packet type identification
- Size tracking for bandwidth analysis

## Usage Examples

### Basic Capture
```bash
./bin/streamripper capture rtsp://192.168.1.100:554/stream
```

### With Custom Output
```bash
./bin/streamripper capture rtsp://192.168.1.100:554/stream \
  --output logs/analysis.json \
  --raw-stream streams/raw.bin
```

### With Duration Limit
```bash
./bin/streamripper capture rtsp://192.168.1.100:554/stream \
  --duration 60 \
  --verbose
```

### CSV Format
```bash
./bin/streamripper capture rtsp://192.168.1.100:554/stream \
  --format csv \
  --output logs/analysis.csv
```

### With Authentication
```bash
./bin/streamripper capture rtsp://admin:password@192.168.1.100:554/stream
```

## Testing

Comprehensive test suite with RSpec:

```bash
bundle exec rspec                    # Run all tests
bundle exec rspec spec/packet_analyzer_spec.rb  # Specific test
bundle exec rspec --format documentation        # Verbose output
```

**Test Coverage**:
- PacketAnalyzer: Payload type mapping, timestamp deviation, statistics
- PacketLogger: JSON/CSV formatting, file I/O, statistics
- StreamSaver: Raw packet saving, directory creation, statistics

## Dependencies

### Runtime
- **thor** (~1.2) - CLI framework
- **json** (~2.6) - JSON handling

### Development
- **rspec** (~3.12) - Testing framework
- **rspec-mocks** (~3.12) - Mocking library
- **pry** (~0.14) - Debugging
- **rubocop** (~1.40) - Code linting

## Installation

```bash
# Clone repository
git clone <repo-url> streamripper-rb
cd streamripper-rb

# Install dependencies
bundle install

# Make executable
chmod +x bin/streamripper

# Run tests
bundle exec rspec
```

## Documentation

- **README.md** - User guide and quick start
- **SETUP.md** - Installation instructions
- **docs/PACKET_ANALYSIS.md** - Detailed packet format documentation
- **docs/TROUBLESHOOTING.md** - Troubleshooting guide
- **examples/usage_examples.sh** - Usage examples
- **examples/config.yml** - Configuration example

## Performance Characteristics

- **Packet Rate**: Typically 100-1000 packets/second depending on stream
- **Memory Usage**: ~50-100MB for typical captures
- **Disk I/O**: Depends on packet size and logging format
- **CPU Usage**: Minimal (mostly I/O bound)

## Forensic Analysis Use Cases

1. **Stream Quality Assessment** - Analyze jitter and frame drops
2. **Packet Loss Detection** - Identify missing packets
3. **Bandwidth Analysis** - Calculate bitrate and utilization
4. **Timing Analysis** - Correlate with system events
5. **Raw Stream Replay** - Re-analyze with different parameters

## Future Enhancements

Potential improvements:
- Support for RTMP streams
- Real-time visualization
- Statistical analysis and reporting
- Integration with Wireshark
- Multi-stream capture
- Database logging
- Web UI for monitoring

## License

MIT License - See LICENSE file for details

## Author

Paul Philippov (themactep@gmail.com)

## Version

0.1.0 - Initial release

