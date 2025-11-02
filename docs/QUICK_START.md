# Streamripper - Quick Start Guide

## 5-Minute Setup

### 1. Install Ruby (if not already installed)

**Ubuntu/Debian:**
```bash
sudo apt-get update && sudo apt-get install ruby-full ruby-dev build-essential
```

**macOS:**
```bash
brew install ruby
```

### 2. Install Streamripper

```bash
cd streamripper-rb
gem install bundler
bundle install
chmod +x bin/streamripper
```

### 3. Verify Installation

```bash
./bin/streamripper --version
bundle exec rspec  # Run tests
```

## Basic Usage

### Capture Stream (Default Settings)

```bash
./bin/streamripper capture rtsp://192.168.1.100:554/stream
```

Output:
- `logs/stream_analysis.json` - Packet analysis
- `streams/raw_stream.bin` - Raw stream data

### Capture for 60 Seconds

```bash
./bin/streamripper capture rtsp://192.168.1.100:554/stream --duration 60
```

### Capture with CSV Output

```bash
./bin/streamripper capture rtsp://192.168.1.100:554/stream \
  --format csv \
  --output logs/analysis.csv
```

### Capture with Authentication

```bash
./bin/streamripper capture rtsp://admin:password@192.168.1.100:554/stream
```

### Verbose Output

```bash
./bin/streamripper capture rtsp://192.168.1.100:554/stream --verbose
```

## Understanding the Output

### JSON Log Example

```json
{
  "packet_number": 1,
  "wallclock_time_ms": 1699000000123,
  "packet_type": "H264",
  "payload_type_code": 96,
  "raw_packet_size": 1500,
  "stream_timestamp": 1000000,
  "sequence_number": 12345,
  "marker_bit": 0,
  "ssrc": 3735928559,
  "timestamp_deviation_ms": 0
}
```

### Key Fields

- **packet_number**: Which packet this is (1st, 2nd, 3rd, etc.)
- **wallclock_time_ms**: When your computer received it
- **packet_type**: Video codec (H264, H265, JPEG, etc.)
- **raw_packet_size**: Size in bytes
- **stream_timestamp**: Timestamp from the camera
- **timestamp_deviation_ms**: Jitter indicator (0 = good, >0 = jitter)

## Common Tasks

### Analyze Captured Data

```bash
# Count total packets
jq 'length' logs/stream_analysis.json

# Find packet types
jq '.[] | .packet_type' logs/stream_analysis.json | sort | uniq -c

# Calculate average packet size
jq '[.[] | .raw_packet_size] | add / length' logs/stream_analysis.json

# Find packets with timestamp issues
jq '.[] | select(.timestamp_deviation_ms != 0)' logs/stream_analysis.json
```

### Check Stream Quality

```bash
# High timestamp deviation = jitter/frame drops
jq '[.[] | .timestamp_deviation_ms] | max' logs/stream_analysis.json

# Check for packet loss (gaps in sequence numbers)
jq '.[] | .sequence_number' logs/stream_analysis.json | sort -n
```

### Calculate Bitrate

```bash
# Assuming 60-second capture
# Total bytes / 60 seconds / 1000 = kbps
jq '[.[] | .raw_packet_size] | add' logs/stream_analysis.json
# Divide result by 60000 for kbps
```

## Troubleshooting

### "Connection refused"

1. Check camera IP: `ping 192.168.1.100`
2. Check RTSP port: `nc -zv 192.168.1.100 554`
3. Test with VLC: `vlc rtsp://192.168.1.100:554/stream`

### "No packets captured"

1. Verify stream is working: `vlc rtsp://192.168.1.100:554/stream`
2. Check firewall: `sudo ufw allow 554`
3. Try different RTSP URL (see examples below)

### "Permission denied"

```bash
chmod +x bin/streamripper
mkdir -p logs streams
chmod 755 logs streams
```

## Camera RTSP URLs

### Hikvision
```
rtsp://admin:password@192.168.1.100:554/Streaming/Channels/101
```

### Dahua
```
rtsp://admin:password@192.168.1.100:554/stream/main
```

### Axis
```
rtsp://admin:password@192.168.1.100:554/axis-media/media.amp
```

### Generic
```
rtsp://192.168.1.100:554/stream
```

## All Command Options

```bash
./bin/streamripper capture <URL> [OPTIONS]

Options:
  -o, --output FILE              Output file for analysis (default: logs/stream_analysis.json)
  -r, --raw-stream FILE          Output file for raw stream (default: streams/raw_stream.bin)
  -f, --format FORMAT            Output format: json, csv, or both (default: json)
  -d, --duration SECONDS         Capture duration in seconds (0 = infinite)
  -m, --max-packets COUNT        Maximum packets to capture (0 = infinite)
  -v, --verbose                  Enable verbose logging
  -h, --help                     Show help message
```

## Next Steps

1. **Read the full README**: `cat README.md`
2. **Check packet analysis docs**: `cat docs/PACKET_ANALYSIS.md`
3. **See troubleshooting guide**: `cat docs/TROUBLESHOOTING.md`
4. **Review examples**: `cat examples/usage_examples.sh`

## Tips & Tricks

### Capture Multiple Cameras

```bash
for camera in 192.168.1.100 192.168.1.101 192.168.1.102; do
  ./bin/streamripper capture rtsp://$camera:554/stream \
    --output "logs/camera_${camera}.json" \
    --duration 60 &
done
wait
```

### Background Capture

```bash
nohup ./bin/streamripper capture rtsp://192.168.1.100:554/stream \
  --duration 3600 \
  > logs/capture.log 2>&1 &
```

### Compress Old Logs

```bash
gzip logs/*.json
```

### Monitor Capture in Real-time

```bash
# In one terminal
./bin/streamripper capture rtsp://192.168.1.100:554/stream --verbose

# In another terminal
tail -f logs/stream_analysis.json | jq '.'
```

## Getting Help

```bash
./bin/streamripper capture --help
```

For detailed help, see:
- README.md - Full documentation
- docs/TROUBLESHOOTING.md - Common issues
- docs/PACKET_ANALYSIS.md - Technical details

