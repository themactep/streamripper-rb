# H.264 Stream Processing Pipeline

## Overview

The streamripper system captures RTSP streams and converts them to playable MP4 files. This document describes the H.264 stream processing pipeline.

## Architecture

```
RTSP Stream
    ↓
RTP Packets (with FU-A fragmentation)
    ↓
Packet Analysis & Filtering
    ↓
H.264 De-fragmentation
    ↓
Individual Frame Files
    ↓
Complete H.264 Stream
    ↓
MP4 Container (via ffmpeg)
    ↓
Playable MP4 File
```

## Processing Steps

### 1. RTP Packet Capture

- Captures RTP packets from RTSP stream
- Extracts payload data from each packet
- Records metadata (RTP timestamp, payload type, sequence number)

### 2. Packet Filtering

Packets are filtered based on:
- **Audio packets** (payload type 97) → Discarded
- **Empty/invalid payloads** → Discarded
- **Reserved NAL types** (30-31) → Discarded
- **Pre-SPS packets** → Discarded (packets before first SPS)

### 3. H.264 De-fragmentation

Handles two types of NAL units:

**Single NAL Units:**
```
Payload → [0x00 0x00 0x01] + Payload
```

**FU-A Fragments (NAL type 28):**
```
Fragment 1 (start_bit=1) → [0x00 0x00 0x01] + NAL_Header + Data
Fragment 2 (start_bit=0) → Data
Fragment 3 (end_bit=1)   → Data
```

### 4. Duplicate SPS/PPS Removal

- Keeps first SPS/PPS at stream beginning
- Removes duplicate SPS/PPS that appear later
- Ensures proper H.264 stream structure

### 5. Frame Grouping

- Groups packets by RTP timestamp
- Creates individual frame files (one per timestamp)
- Preserves frame boundaries

### 6. Complete Stream Creation

- Concatenates all de-fragmented packets
- Applies duplicate SPS/PPS filter
- Uses 3-byte start codes (MP4 compatible)

### 7. MP4 Generation

- Reads H.264 stream
- Uses ffmpeg to create MP4 container
- Sets correct frame rate from RTP timestamps
- Adds moov atom at beginning for streaming

## Key Algorithms

### Frame Rate Calculation

```ruby
frame_rate = unique_rtp_timestamps / capture_duration
```

Example: 45 unique timestamps in 3 seconds = 15 fps

### NAL Unit Type Detection

```ruby
nal_unit_type = first_byte & 0x1F
```

Common types:
- 1: Non-IDR slice (P-frame)
- 5: IDR slice (I-frame)
- 7: SPS (Sequence Parameter Set)
- 8: PPS (Picture Parameter Set)
- 28: FU-A (Fragmentation Unit A)

### Start Code Format

**3-byte start code (MP4 compatible):**
```
0x00 0x00 0x01
```

**4-byte start code (File format):**
```
0x00 0x00 0x00 0x01
```

## Output Structure

```
logs/streams/{host}/{scan_id}/
├── analysis.json              # Packet analysis
├── raw_stream.bin             # Raw RTP data
├── stream.h264                # Complete H.264 stream
├── stream.mp4                 # Playable MP4 file
├── frames/                    # Individual frame files
│   ├── frame00001.bin        # SPS
│   ├── frame00002.bin        # PPS
│   ├── frame00003.bin        # IDR frame
│   └── ...
└── discarded_packets/         # Analysis of discarded packets
    ├── discarded_packets.bin
    ├── discarded_packets.json
    ├── summary.txt
    └── audio/                 # Audio packets (if any)
```

## Error Handling

### Common Issues

1. **Bytestream overread errors**
   - Cause: Incomplete or corrupted NAL units
   - Solution: Validate NAL unit boundaries

2. **Decoding errors**
   - Cause: Missing SPS/PPS or duplicate SPS/PPS
   - Solution: Ensure SPS/PPS at stream beginning only

3. **Frame rate mismatch**
   - Cause: Hardcoded frame rate vs. actual stream rate
   - Solution: Calculate from RTP timestamps

## Performance Metrics

- **Capture duration:** 3 seconds
- **Frame count:** ~45 frames
- **Frame rate:** ~15 fps
- **H.264 stream size:** ~330 KB
- **MP4 file size:** ~260 KB
- **Decode errors:** 0
- **Processing time:** <1 second

## Testing & Validation

### Verification Steps

1. Check H.264 stream with ffmpeg debug output
2. Extract frames from MP4 and compare with original
3. Verify frame rate and duration
4. Test playback in multiple players
5. Validate decode error count

### Tools Used

- `ffmpeg -v debug` - Detailed H.264 analysis
- `ffprobe` - Stream information
- `mpv` - Video playback testing
- `cmp -l` - Byte-level file comparison
- `hexdump -C` - Hex dump inspection

