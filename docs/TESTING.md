# Testing Streamripper

## Test Files

### 1. test_syntax.rb
Basic syntax check - verifies all modules load correctly.

```bash
ruby test_syntax.rb
```

Expected output:
```
✓ All modules loaded successfully
✓ RTSPFetcher: Streamripper::RTSPFetcher
✓ PacketAnalyzer: Streamripper::PacketAnalyzer
✓ PacketLogger: Streamripper::PacketLogger
✓ StreamSaver: Streamripper::StreamSaver
✓ CLI: Streamripper::CLI
✓ Version: 0.1.0
✓ PacketAnalyzer instantiated
✓ Packet analysis works
  - Packet type: H264
  - Packet number: 1

✅ All syntax checks passed!
```

### 2. test_mock_capture.rb
Simulates capturing 10 RTP packets without needing a real camera.

```bash
ruby test_mock_capture.rb
```

Tests:
- Component initialization
- Packet analysis
- JSON logging
- Binary stream saving
- Statistics calculation

### 3. test_integration.rb
Comprehensive integration test covering all features.

```bash
ruby test_integration.rb
```

Tests:
- JSON format output
- CSV format output
- Dual format (JSON + CSV)
- Timestamp deviation tracking
- Payload type mapping
- Packet size calculation
- Statistics tracking

## RSpec Tests

Run the full RSpec test suite:

```bash
bundle exec rspec
```

Run specific test file:

```bash
bundle exec rspec spec/packet_analyzer_spec.rb
```

Run with verbose output:

```bash
bundle exec rspec --format documentation
```

## Testing with Real Camera

Once Ruby is installed:

```bash
# 1. Install dependencies
bundle install

# 2. Run syntax check
ruby test_syntax.rb

# 3. Run mock tests
ruby test_mock_capture.rb
ruby test_integration.rb

# 4. Test with real camera (10 packets)
./bin/streamripper capture rtsp://thingino:thingino@192.168.88.31/ch0 \
  --max-packets 10 \
  --verbose

# 5. Analyze results
jq '.' logs/stream_analysis.json
```

## Expected Test Results

All tests should pass with:
- ✓ Modules load correctly
- ✓ Packet analysis works
- ✓ JSON output is valid
- ✓ CSV output is valid
- ✓ Binary stream is saved
- ✓ Timestamp deviation calculated
- ✓ Payload types mapped correctly
- ✓ Packet sizes calculated correctly
- ✓ Statistics tracked

## Troubleshooting Tests

If tests fail:

1. Check Ruby version: `ruby --version` (need 2.7+)
2. Check dependencies: `bundle install`
3. Run syntax check first: `ruby test_syntax.rb`
4. Check file permissions: `chmod +x bin/streamripper`
5. Check temp directory: `/tmp` must be writable

## Performance Testing

To test with larger captures:

```bash
# Capture 1000 packets
./bin/streamripper capture rtsp://thingino:thingino@192.168.88.31/ch0 \
  --max-packets 1000 \
  --verbose

# Analyze performance
time ./bin/streamripper capture rtsp://thingino:thingino@192.168.88.31/ch0 \
  --duration 60
```

## Continuous Integration

For CI/CD pipelines:

```bash
#!/bin/bash
set -e

# Install
bundle install

# Test
ruby test_syntax.rb
ruby test_mock_capture.rb
ruby test_integration.rb
bundle exec rspec

echo "✅ All tests passed"
```

