# Testing Streamripper with Your Camera

## Camera Details

**URL**: `rtsp://thingino:thingino@192.168.88.31/ch0`
**Type**: Thingino-based IP camera
**Credentials**: thingino / thingino

## Pre-Test Verification

Before running the application, verify your camera is accessible:

```bash
# 1. Check if camera is reachable
ping 192.168.88.31

# 2. Check if RTSP port is open
nc -zv 192.168.88.31 554

# 3. Test with VLC (optional)
vlc rtsp://thingino:thingino@192.168.88.31/ch0
```

## Installation

```bash
# 1. Install Ruby (if not already installed)
# Ubuntu/Debian:
sudo apt-get update && sudo apt-get install ruby-full ruby-dev build-essential

# macOS:
brew install ruby

# 2. Install dependencies
cd streamripper-rb
gem install bundler
bundle install
chmod +x bin/streamripper

# 3. Verify installation
bundle exec rspec
```

## Test Captures

### Test 1: Quick 10-Packet Capture

```bash
./bin/streamripper capture rtsp://thingino:thingino@192.168.88.31/ch0 \
  --max-packets 10 \
  --verbose
```

**Expected Output:**
- Logs to: `logs/stream_analysis.json`
- Raw stream to: `streams/raw_stream.bin`
- Console shows: Packet capture progress

### Test 2: 30-Second Capture

```bash
./bin/streamripper capture rtsp://thingino:thingino@192.168.88.31/ch0 \
  --duration 30 \
  --verbose
```

**Expected Output:**
- ~100-1000 packets captured (depending on bitrate)
- JSON log with packet analysis
- Raw stream file for forensics

### Test 3: CSV Format

```bash
./bin/streamripper capture rtsp://thingino:thingino@192.168.88.31/ch0 \
  --duration 30 \
  --format csv \
  --output logs/camera_analysis.csv \
  --verbose
```

**Expected Output:**
- CSV file with headers and packet data
- Easy to import into Excel/spreadsheet

### Test 4: Both Formats

```bash
./bin/streamripper capture rtsp://thingino:thingino@192.168.88.31/ch0 \
  --duration 30 \
  --format both \
  --output logs/camera_analysis \
  --verbose
```

**Expected Output:**
- `logs/camera_analysis.json` - JSON format
- `logs/camera_analysis.csv` - CSV format
- `streams/raw_stream.bin` - Raw stream

### Test 5: Extended Capture (5 minutes)

```bash
./bin/streamripper capture rtsp://thingino:thingino@192.168.88.31/ch0 \
  --duration 300 \
  --output logs/camera_5min.json \
  --raw-stream streams/camera_5min.bin \
  --verbose
```

**Expected Output:**
- Comprehensive analysis of 5-minute stream
- Detailed jitter and timing analysis
- Large raw stream file for forensics

## Analyzing Results

### View JSON Results

```bash
# Pretty print JSON
cat logs/stream_analysis.json | jq '.'

# Count packets
jq 'length' logs/stream_analysis.json

# View first packet
jq '.[0]' logs/stream_analysis.json

# View last packet
jq '.[-1]' logs/stream_analysis.json
```

### Analyze Packet Types

```bash
# Find all packet types
jq '.[] | .packet_type' logs/stream_analysis.json | sort | uniq -c

# Find packets with jitter
jq '.[] | select(.timestamp_deviation_ms != 0)' logs/stream_analysis.json | head -20
```

### Calculate Statistics

```bash
# Average packet size
jq '[.[] | .raw_packet_size] | add / length' logs/stream_analysis.json

# Total bytes captured
jq '[.[] | .raw_packet_size] | add' logs/stream_analysis.json

# Packet rate (divide by duration)
# Example: 5000 packets / 30 seconds = 166.67 pkt/s

# Bitrate (total bytes * 8 / duration / 1000)
# Example: 7500000 bytes * 8 / 30 / 1000 = 2000 kbps
```

### Check for Issues

```bash
# Find timestamp deviations (jitter)
jq '[.[] | .timestamp_deviation_ms] | max' logs/stream_analysis.json

# Find sequence number gaps (packet loss)
jq '.[] | .sequence_number' logs/stream_analysis.json | sort -n | uniq -c | grep -v "^ *1 "

# Check marker bits
jq '.[] | select(.marker_bit == 1)' logs/stream_analysis.json | wc -l
```

## Expected Results for Thingino Camera

Based on typical Thingino camera streams:

**Codec**: Likely H264 (payload type 96)
**Packet Rate**: 100-500 packets/second
**Packet Size**: 1000-1500 bytes typical
**Bitrate**: 500-2000 kbps typical
**Jitter**: Low (0-10ms deviation typical)

## Troubleshooting

### "Connection refused"

```bash
# Verify camera is reachable
ping 192.168.88.31

# Check if RTSP port is open
nc -zv 192.168.88.31 554

# Try with VLC
vlc rtsp://thingino:thingino@192.168.88.31/ch0
```

### "No packets captured"

1. Verify stream is working in VLC
2. Check firewall rules
3. Verify credentials are correct
4. Try different RTSP paths (some cameras use different URLs)

### "Authentication failed"

```bash
# Verify credentials
# Username: thingino
# Password: thingino

# Try URL encoding if password has special characters
# Example: password "p@ss" becomes "p%40ss"
```

### "Connection timeout"

1. Check network connectivity
2. Verify camera IP address
3. Check if camera is powered on
4. Try from different network

## Background Capture

To capture in the background:

```bash
nohup ./bin/streamripper capture rtsp://thingino:thingino@192.168.88.31/ch0 \
  --duration 3600 \
  --output logs/camera_1hour.json \
  --raw-stream streams/camera_1hour.bin \
  > logs/capture.log 2>&1 &

# Check progress
tail -f logs/capture.log

# Check process
ps aux | grep streamripper
```

## Multiple Captures

If you have multiple cameras:

```bash
# Capture from multiple cameras simultaneously
for i in 1 2 3; do
  nohup ./bin/streamripper capture rtsp://thingino:thingino@192.168.88.$((30+i))/ch0 \
    --duration 300 \
    --output "logs/camera_$i.json" \
    > "logs/camera_$i.log" 2>&1 &
done

wait
echo "All captures complete"
```

## Performance Monitoring

Monitor capture in real-time:

```bash
# Terminal 1: Start capture
./bin/streamripper capture rtsp://thingino:thingino@192.168.88.31/ch0 --verbose

# Terminal 2: Monitor progress
watch -n 1 'jq "length" logs/stream_analysis.json'

# Terminal 3: Monitor file sizes
watch -n 1 'ls -lh logs/ streams/'
```

## Data Analysis Examples

### Stream Quality Report

```bash
#!/bin/bash

LOG_FILE="logs/stream_analysis.json"

echo "=== Stream Quality Report ==="
echo "Total Packets: $(jq 'length' $LOG_FILE)"
echo "Packet Types: $(jq '.[] | .packet_type' $LOG_FILE | sort | uniq -c)"
echo "Average Packet Size: $(jq '[.[] | .raw_packet_size] | add / length' $LOG_FILE) bytes"
echo "Max Timestamp Deviation: $(jq '[.[] | .timestamp_deviation_ms] | max' $LOG_FILE) ms"
echo "Min Timestamp Deviation: $(jq '[.[] | .timestamp_deviation_ms] | min' $LOG_FILE) ms"
```

### Export to CSV for Excel

```bash
# Convert JSON to CSV (already done with --format csv)
# Or manually:
jq -r '.[] | [.packet_number, .wallclock_time_ms, .packet_type, .raw_packet_size, .timestamp_deviation_ms] | @csv' logs/stream_analysis.json > analysis.csv
```

## Next Steps

1. **Install Ruby** on your system
2. **Run bundle install** to install dependencies
3. **Test with quick capture** (10 packets)
4. **Analyze results** using jq
5. **Run longer captures** for detailed analysis
6. **Check for issues** (jitter, packet loss, etc.)

## Support

If you encounter issues:

1. Check **docs/TROUBLESHOOTING.md**
2. Verify camera connectivity
3. Check firewall rules
4. Review **docs/PACKET_ANALYSIS.md** for technical details
5. See **QUICK_START.md** for quick reference

---

**Camera URL**: rtsp://thingino:thingino@192.168.88.31/ch0
**Status**: Ready for testing
**Expected Success**: High (standard RTSP stream)

