# Troubleshooting Guide

## Installation Issues

### Bundle Install Fails

**Problem**: `bundle install` fails with gem compilation errors

**Solutions**:
```bash
# Update bundler
gem update bundler

# Install build tools (Ubuntu/Debian)
sudo apt-get install build-essential ruby-dev

# Try install again with verbose output
bundle install --verbose
```

### Ruby Version Mismatch

**Problem**: `Ruby version requirement not met`

**Solution**:
```bash
# Check Ruby version
ruby --version

# Install correct Ruby version using rbenv or rvm
rbenv install 3.0.0
rbenv local 3.0.0
```

## Connection Issues

### Cannot Connect to Camera

**Problem**: `Connection refused` or `Connection timeout`

**Diagnostics**:
```bash
# Check if camera is reachable
ping <camera-ip>

# Check if RTSP port is open
nc -zv <camera-ip> 554

# Test with VLC
vlc rtsp://<camera-ip>:554/stream
```

**Solutions**:
1. Verify camera IP address and port
2. Check firewall rules (port 554 must be open)
3. Verify RTSP URL format
4. Check camera credentials if authentication required
5. Ensure camera is powered on and network connected

### Authentication Failed

**Problem**: `401 Unauthorized` or `403 Forbidden`

**Solution**:
```bash
# Use correct credentials in URL
./bin/streamripper capture rtsp://username:password@camera-ip:554/stream

# URL encode special characters in password
# Example: password "p@ss" becomes "p%40ss"
./bin/streamripper capture rtsp://user:p%40ss@camera-ip:554/stream
```

### Invalid RTSP URL

**Problem**: `Invalid URL format` or `Connection reset`

**Common URL Formats**:
```
# Generic
rtsp://camera-ip:554/stream

# Hikvision
rtsp://admin:password@camera-ip:554/Streaming/Channels/101

# Dahua
rtsp://admin:password@camera-ip:554/stream/main

# Axis
rtsp://admin:password@camera-ip:554/axis-media/media.amp

# Uniview
rtsp://admin:password@camera-ip:554/media/video1
```

## Stream Analysis Issues

### No Packets Captured

**Problem**: Capture runs but no packets are logged

**Causes and Solutions**:
1. Stream not actually sending data
   - Verify with VLC: `vlc rtsp://camera-ip:554/stream`
   
2. Firewall blocking packets
   - Check firewall rules
   - Try from different network
   
3. Camera not configured for streaming
   - Check camera web interface
   - Verify stream is enabled

### Timestamp Deviations Too High

**Problem**: Large timestamp deviations indicate stream quality issues

**Causes**:
- Network congestion
- Packet loss
- Camera clock issues
- Insufficient bandwidth

**Solutions**:
1. Check network bandwidth: `iperf3 -c <camera-ip>`
2. Monitor packet loss: `ping -c 100 <camera-ip>`
3. Check camera logs for errors
4. Reduce stream resolution/bitrate on camera
5. Use wired connection instead of WiFi

### Packet Loss Detected

**Problem**: Missing sequence numbers in logs

**Analysis**:
```bash
# Extract sequence numbers from JSON
jq '.[] | .sequence_number' logs/stream_analysis.json | sort -n

# Find gaps
# If you see: 100, 101, 102, 105, 106
# Packets 103-104 were lost
```

**Solutions**:
1. Check network stability
2. Verify camera buffer settings
3. Reduce capture duration to test
4. Check for CPU/memory issues on capture machine

## Performance Issues

### High CPU Usage

**Problem**: Streamripper using excessive CPU

**Solutions**:
1. Reduce logging verbosity: remove `--verbose` flag
2. Limit packet capture: use `--max-packets`
3. Use CSV format instead of JSON (faster)
4. Reduce stream resolution on camera

### High Memory Usage

**Problem**: Memory usage grows over time

**Solutions**:
1. Limit capture duration: use `--duration`
2. Limit packet count: use `--max-packets`
3. Reduce payload size (camera setting)
4. Run multiple shorter captures instead of one long capture

### Slow File I/O

**Problem**: Disk write is bottleneck

**Solutions**:
1. Use SSD instead of HDD
2. Write to local disk instead of network share
3. Reduce logging frequency
4. Use CSV format (smaller file size)

## File Issues

### Cannot Write to Output Directory

**Problem**: `Permission denied` when writing logs

**Solution**:
```bash
# Check directory permissions
ls -la logs/

# Create directory with proper permissions
mkdir -p logs
chmod 755 logs

# Run with appropriate user
sudo ./bin/streamripper capture rtsp://camera-ip:554/stream
```

### Output Files Too Large

**Problem**: Log files consuming too much disk space

**Solutions**:
1. Limit capture duration: `--duration 60`
2. Limit packet count: `--max-packets 10000`
3. Use CSV format (smaller than JSON)
4. Compress old logs: `gzip logs/*.json`
5. Implement log rotation

### Raw Stream File Corrupted

**Problem**: Cannot replay raw stream

**Solutions**:
1. Verify file size is reasonable
2. Check file permissions
3. Verify capture completed successfully
4. Try with smaller capture duration

## Debugging

### Enable Verbose Logging

```bash
./bin/streamripper capture rtsp://camera-ip:554/stream --verbose
```

### Check System Resources

```bash
# Monitor CPU and memory
top -p $(pgrep -f streamripper)

# Check disk space
df -h

# Monitor network
nethogs
```

### Analyze Captured Data

```bash
# Count packets
jq 'length' logs/stream_analysis.json

# Find packet type distribution
jq '.[] | .packet_type' logs/stream_analysis.json | sort | uniq -c

# Calculate average packet size
jq '[.[] | .raw_packet_size] | add / length' logs/stream_analysis.json

# Find timestamp deviations
jq '.[] | select(.timestamp_deviation_ms != 0)' logs/stream_analysis.json
```

## Getting Help

1. Check logs for error messages
2. Run with `--verbose` flag for detailed output
3. Verify camera connectivity with VLC
4. Check camera documentation for RTSP URL format
5. Review packet analysis documentation in docs/PACKET_ANALYSIS.md

