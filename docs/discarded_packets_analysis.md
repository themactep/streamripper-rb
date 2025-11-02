# Discarded Packets Analysis

## Overview

The streamripper system automatically collects and analyzes all packets that are discarded during stream processing. This provides visibility into stream quality and helps identify issues.

## Discard Reasons

### 1. Audio Packets (Payload Type 97)

**Reason:** Audio is not used for video processing

**Characteristics:**
- Payload type: 97 (MPEG4-GENERIC)
- Separate RTP stream from video
- Saved separately in `audio/` subdirectory

**Example:**
```
Audio Packets (Payload Type 97): 150
Total audio data: 45000 bytes
Audio Codec: MPEG4-GENERIC
```

### 2. Empty/Invalid Payloads

**Reason:** Packets with no data or corrupted payloads

**Characteristics:**
- Payload length < 1 byte
- Malformed RTP packets
- Network transmission errors

### 3. Reserved NAL Types (30-31)

**Reason:** Proprietary or reserved NAL types

**Characteristics:**
- NAL type 30: Reserved
- NAL type 31: Reserved
- Often Dolby Vision or other metadata
- Not decodable as video

### 4. Pre-SPS Packets

**Reason:** Packets arriving before first SPS

**Characteristics:**
- Occur at stream start
- Typically P-frame fragments
- Cannot be decoded without SPS/PPS
- Automatically skipped

## Output Files

### discarded_packets.bin

Raw binary concatenation of all discarded packet payloads.

**Usage:**
- Low-level analysis
- Debugging stream issues
- Custom packet inspection

**Size:** Variable (0 bytes if no discarded packets)

### discarded_packets.json

Complete analysis data for each discarded packet in JSON format.

**Fields:**
```json
{
  "packet_number": 1,
  "rtp_timestamp_raw": 4072820873,
  "payload_type_code": 97,
  "packet_type": "MPEG4-GENERIC",
  "discard_reason": "Audio packet (payload type 97)",
  "payload_size": 256,
  "sequence_number": 15809
}
```

### summary.txt

Human-readable summary report.

**Example:**
```
Discarded Packets Analysis
==================================================
Total discarded packets: 150

Discard Reasons:
  Audio packet (payload type 97): 150

Payload Type Distribution:
  MPEG4-GENERIC (97): 150
```

### audio/ Subdirectory

Separate analysis for audio packets (if any exist).

**Files:**
- `audio_packets.bin` - Raw audio data
- `audio_packets.json` - Audio packet analysis
- `summary.txt` - Audio-specific summary

**Audio Summary Example:**
```
Audio Packets Analysis
==================================================
Total audio packets: 150
Total audio data: 45000 bytes

Audio Codec: MPEG4-GENERIC
Payload Type: 97

Unique RTP Timestamps: 75
Average packets per timestamp: 2.0
```

## Analysis Examples

### Clean Stream (No Discarded Packets)

```
Discarded Packets Analysis
==================================================
Total discarded packets: 0

No packets discarded - stream is clean!
```

**Interpretation:** Stream is well-formed with no issues.

### Stream with Audio

```
Discarded Packets Analysis
==================================================
Total discarded packets: 150

Discard Reasons:
  Audio packet (payload type 97): 150
```

**Interpretation:** Audio track present but not used (expected).

### Stream with Metadata

```
Discarded Packets Analysis
==================================================
Total discarded packets: 5

Discard Reasons:
  Reserved NAL type (30): 3
  Reserved NAL type (31): 2
```

**Interpretation:** Dolby Vision or proprietary metadata present.

### Stream with Pre-SPS Packets

```
Discarded Packets Analysis
==================================================
Total discarded packets: 3

Discard Reasons:
  Pre-SPS packet (P-frame): 3
```

**Interpretation:** Stream started with P-frames before SPS (normal).

## Troubleshooting

### High Discard Rate

**Possible causes:**
- Network packet loss
- Malformed RTSP stream
- Incompatible camera firmware

**Action:** Check raw_stream.bin and analysis.json for patterns.

### Unexpected Audio Packets

**Possible causes:**
- Camera configured to send audio
- Audio codec not supported

**Action:** Check audio/ subdirectory for codec information.

### Reserved NAL Types

**Possible causes:**
- Dolby Vision metadata
- Proprietary camera extensions

**Action:** These are safe to discard; video will still play.

## Integration with Monitoring

The discarded packets analysis can be used for:

1. **Stream Quality Monitoring**
   - Track discard rate over time
   - Identify problematic streams

2. **Debugging**
   - Analyze packet structure
   - Identify corruption patterns

3. **Statistics**
   - Audio packet frequency
   - Metadata presence
   - Stream health metrics

## Best Practices

1. **Review summary.txt first** - Quick overview of issues
2. **Check audio/ subdirectory** - If audio packets exist
3. **Use JSON for automation** - Parse discarded_packets.json
4. **Compare across captures** - Identify trends
5. **Archive for analysis** - Keep historical data

