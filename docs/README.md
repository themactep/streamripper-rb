# Streamripper Documentation

## Overview

This directory contains comprehensive documentation for the streamripper RTSP to MP4 conversion system.

## Documents

### [h264_start_codes.md](h264_start_codes.md)

**Critical Finding:** H.264 Start Code Format Issue

Documents the discovery and fix for H.264 decoding errors caused by incorrect start code format.

**Key Points:**
- Problem: 4-byte start codes causing MP4 corruption
- Solution: Use 3-byte start codes (MP4 compatible)
- Result: 0 decode errors, perfect playback
- Investigation: Byte-level file comparison methodology

**Read this if:** You're experiencing decoding errors or want to understand the MP4 format.

### [h264_stream_processing.md](h264_stream_processing.md)

**Complete H.264 Processing Pipeline**

Describes the entire stream processing architecture from RTP capture to MP4 generation.

**Sections:**
- Architecture overview
- Processing steps (7 stages)
- Key algorithms
- Output structure
- Error handling
- Performance metrics
- Testing & validation

**Read this if:** You want to understand how the system works or need to debug stream issues.

### [discarded_packets_analysis.md](discarded_packets_analysis.md)

**Discarded Packets Analysis Feature**

Documents the automatic packet filtering and analysis system.

**Sections:**
- Discard reasons (4 types)
- Output files (bin, json, txt)
- Analysis examples
- Troubleshooting guide
- Integration with monitoring
- Best practices

**Read this if:** You want to understand packet filtering or analyze stream quality.

## Quick Start

1. **First time?** Start with [h264_stream_processing.md](h264_stream_processing.md)
2. **Debugging errors?** Check [h264_start_codes.md](h264_start_codes.md)
3. **Analyzing packets?** See [discarded_packets_analysis.md](discarded_packets_analysis.md)

## Key Findings

### H.264 Start Code Format (Critical)

MP4 containers use **3-byte start codes** (`0x00 0x00 0x01`), not 4-byte start codes (`0x00 0x00 0x00 0x01`).

Using the wrong format causes:
- Stream corruption
- Decoding errors
- Unreliable playback

**Solution:** Always use 3-byte start codes for MP4-compatible H.264 streams.

### Stream Processing Pipeline

The system processes RTSP streams through 7 stages:
1. RTP packet capture
2. Packet filtering
3. H.264 de-fragmentation
4. Duplicate SPS/PPS removal
5. Frame grouping
6. Complete stream creation
7. MP4 generation

Each stage is critical for producing clean, playable output.

### Packet Filtering

The system automatically discards:
- Audio packets (payload type 97)
- Empty/invalid payloads
- Reserved NAL types (30-31)
- Pre-SPS packets

All discarded packets are saved for analysis.

## Performance Metrics

- **Capture duration:** 3 seconds
- **Frame count:** ~45 frames
- **Frame rate:** ~15 fps
- **H.264 stream size:** ~330 KB
- **MP4 file size:** ~260 KB
- **Decode errors:** 0
- **Processing time:** <1 second

## Testing & Validation

### Verification Checklist

- [ ] H.264 stream has 0 decode errors
- [ ] MP4 plays in multiple players
- [ ] Frame rate is correct
- [ ] Duration is accurate
- [ ] No visual artifacts
- [ ] Audio packets properly discarded
- [ ] Discarded packets analysis complete

### Tools Used

- `ffmpeg -v debug` - H.264 analysis
- `ffprobe` - Stream information
- `mpv` - Playback testing
- `cmp -l` - Byte comparison
- `hexdump -C` - Hex inspection

## Contributing

When adding new features or fixing bugs:

1. Document the change
2. Add to appropriate doc file
3. Update this README if needed
4. Include examples and test results

## Version History

### v1.0 (2025-11-01)

- ✅ H.264 RTP de-fragmentation
- ✅ MP4 generation with correct frame rate
- ✅ Packet filtering and analysis
- ✅ 0 decode errors
- ✅ Perfect playback quality

**Critical Fix:** H.264 start code format (3-byte vs 4-byte)

## Support

For issues or questions:

1. Check the relevant documentation file
2. Review the troubleshooting sections
3. Examine discarded_packets analysis
4. Use ffmpeg debug output for detailed diagnostics

