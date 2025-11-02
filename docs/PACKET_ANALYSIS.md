# Packet Analysis Documentation

## Overview

Streamripper analyzes RTP (Real-time Transport Protocol) packets from RTSP streams and logs detailed information about each packet for forensic analysis.

## RTP Packet Structure

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|V=2|P|X|  CC   |M|     PT      |       sequence number         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           timestamp                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           synchronization source (SSRC) identifier            |
+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
|            contributing source (CSRC) identifiers             |
|                             ....                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

## Logged Fields

### packet_number
- **Type**: Integer
- **Description**: Sequential packet number in the stream (1-based)
- **Example**: 1, 2, 3, ...

### wallclock_time_ms
- **Type**: Integer
- **Description**: System time when packet was received in milliseconds since epoch
- **Example**: 1699000000123
- **Use**: Correlate with system events and other logs

### packet_type
- **Type**: String
- **Description**: Human-readable RTP payload type name
- **Common Values**: H264, H265, JPEG, PCMU, G722, etc.
- **Example**: "H264"

### payload_type_code
- **Type**: Integer
- **Description**: Numeric RTP payload type code (0-127)
- **Example**: 96 (H264)
- **Reference**: RFC 3551 for standard payload types

### raw_packet_size
- **Type**: Integer
- **Description**: Total size of the RTP packet in bytes including header and payload
- **Calculation**: 12 (header) + CC*4 (CSRC) + ext_size + payload_size
- **Example**: 1500

### stream_timestamp
- **Type**: Integer
- **Description**: RTP timestamp from packet header (32-bit)
- **Note**: Increments based on media clock, not wall clock
- **Example**: 1000000

### sequence_number
- **Type**: Integer
- **Description**: RTP sequence number (16-bit)
- **Note**: Increments by 1 for each packet (may wrap around)
- **Example**: 12345

### marker_bit
- **Type**: Integer (0 or 1)
- **Description**: RTP marker bit
- **Meaning**: 
  - 1 = Last packet of a frame (for video)
  - 0 = Not the last packet
- **Example**: 1

### ssrc
- **Type**: Integer
- **Description**: Synchronization Source identifier (32-bit)
- **Note**: Identifies the stream source
- **Example**: 3735928559

### timestamp_deviation_ms
- **Type**: Integer
- **Description**: Deviation from expected timestamp increment
- **Calculation**: Actual_increment - Expected_increment
- **Meaning**:
  - 0 = Timestamp increment as expected
  - Positive = Timestamp increment larger than expected (jitter)
  - Negative = Timestamp increment smaller than expected (jitter)
- **Example**: 0, 5, -3

## Timestamp Deviation Analysis

### What is Timestamp Deviation?

The RTP timestamp should increment at a constant rate based on the media clock. Deviations indicate:

1. **Jitter**: Variation in packet arrival timing
2. **Frame drops**: Missing packets or frames
3. **Clock issues**: Problems with the source clock
4. **Network issues**: Packet loss or reordering

### Calculation Method

```
expected_increment = increment_from_first_two_packets
actual_increment = current_timestamp - previous_timestamp
deviation = actual_increment - expected_increment
```

### Interpretation

- **Deviation = 0**: Perfect timing, no jitter
- **Deviation > 0**: Timestamp jumped forward (possible frame drop)
- **Deviation < 0**: Timestamp increment smaller than expected
- **Large deviations**: Indicates stream quality issues

## Payload Type Codes

Common RTP payload types:

| Code | Type | Description |
|------|------|-------------|
| 0 | PCMU | Audio - PCM mu-law |
| 3 | GSM | Audio - GSM |
| 8 | PCMA | Audio - PCM A-law |
| 9 | G722 | Audio - G.722 |
| 14 | MPA | Audio - MPEG Audio |
| 26 | JPEG | Video - JPEG |
| 31 | H261 | Video - H.261 |
| 32 | MPV | Video - MPEG-1/2 |
| 33 | MP2T | Video - MPEG-2 Transport |
| 34 | H263 | Video - H.263 |
| 96 | H264 | Video - H.264 (dynamic) |
| 97 | H265 | Video - H.265 (dynamic) |

## Output Examples

### JSON Format

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

### CSV Format

```
packet_number,wallclock_time_ms,packet_type,payload_type_code,raw_packet_size,stream_timestamp,sequence_number,marker_bit,ssrc,timestamp_deviation_ms
1,1699000000123,H264,96,1500,1000000,12345,0,3735928559,0
```

## Forensic Analysis Use Cases

### 1. Stream Quality Assessment

Analyze timestamp deviations to identify:
- Jitter patterns
- Frame drops
- Clock synchronization issues

### 2. Packet Loss Detection

Compare sequence numbers to identify:
- Missing packets
- Out-of-order packets
- Duplicate packets

### 3. Bandwidth Analysis

Use raw_packet_size to calculate:
- Average bitrate
- Peak bitrate
- Bandwidth utilization

### 4. Timing Analysis

Use wallclock_time_ms to correlate:
- Stream events with system events
- Multiple camera streams
- Network issues

### 5. Raw Stream Replay

Use raw stream file to:
- Re-analyze packets with different parameters
- Extract specific frames
- Integrate with other tools (Wireshark, ffmpeg)

## Performance Metrics

### Packet Rate
```
packet_rate = total_packets / duration_seconds
```

### Average Packet Size
```
avg_size = total_bytes / total_packets
```

### Bitrate
```
bitrate_kbps = (total_bytes * 8) / (duration_seconds * 1000)
```

### Timestamp Deviation Statistics
```
avg_deviation = sum(deviations) / count(deviations)
max_deviation = max(deviations)
min_deviation = min(deviations)
```

