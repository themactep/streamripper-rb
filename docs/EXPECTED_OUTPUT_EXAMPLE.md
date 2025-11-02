# Expected Output Example

## When Running Against Your Camera

```bash
./bin/streamripper capture rtsp://thingino:thingino@192.168.88.31/ch0 --duration 30 --verbose
```

## Console Output

```
Streamripper v0.1.0
============================================================
RTSP Stream Analyzer
============================================================
URL: rtsp://thingino:thingino@192.168.88.31/ch0
Output: logs/stream_analysis.json
Raw Stream: streams/raw_stream.bin
Format: json
Duration: 30s
Max Packets: infinite
============================================================

Capturing packets...

Captured 100 packets (33.33 pkt/s)
Captured 200 packets (33.33 pkt/s)
Captured 300 packets (33.33 pkt/s)
Captured 400 packets (33.33 pkt/s)
Captured 500 packets (33.33 pkt/s)

============================================================
CAPTURE SUMMARY
============================================================
Total Packets Captured: 523
Duration: 30.02s
Packet Rate: 17.42 pkt/s

Analysis Log:
  File: logs/stream_analysis.json
  Format: json

Raw Stream:
  File: streams/raw_stream.bin
  Size: 785400 bytes
============================================================
```

## JSON Output Example

File: `logs/stream_analysis.json`

```json
[
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
},
{
  "packet_number": 2,
  "wallclock_time_ms": 1699000000133,
  "packet_type": "H264",
  "payload_type_code": 96,
  "raw_packet_size": 1500,
  "stream_timestamp": 1003600,
  "sequence_number": 12346,
  "marker_bit": 0,
  "ssrc": 3735928559,
  "timestamp_deviation_ms": 0
},
{
  "packet_number": 3,
  "wallclock_time_ms": 1699000000143,
  "packet_type": "H264",
  "payload_type_code": 96,
  "raw_packet_size": 1450,
  "stream_timestamp": 1007200,
  "sequence_number": 12347,
  "marker_bit": 1,
  "ssrc": 3735928559,
  "timestamp_deviation_ms": 0
},
{
  "packet_number": 4,
  "wallclock_time_ms": 1699000000153,
  "packet_type": "H264",
  "payload_type_code": 96,
  "raw_packet_size": 1500,
  "stream_timestamp": 1010800,
  "sequence_number": 12348,
  "marker_bit": 0,
  "ssrc": 3735928559,
  "timestamp_deviation_ms": 0
}
]
```

## CSV Output Example

File: `logs/stream_analysis.csv`

```
packet_number,wallclock_time_ms,packet_type,payload_type_code,raw_packet_size,stream_timestamp,sequence_number,marker_bit,ssrc,timestamp_deviation_ms
1,1699000000123,H264,96,1500,1000000,12345,0,3735928559,0
2,1699000000133,H264,96,1500,1003600,12346,0,3735928559,0
3,1699000000143,H264,96,1450,1007200,12347,1,3735928559,0
4,1699000000153,H264,96,1500,1010800,12348,0,3735928559,0
5,1699000000163,H264,96,1500,1014400,12349,0,3735928559,0
```

## Analysis Commands and Results

### Count Total Packets

```bash
$ jq 'length' logs/stream_analysis.json
523
```

### Find Packet Types

```bash
$ jq '.[] | .packet_type' logs/stream_analysis.json | sort | uniq -c
    523 H264
```

### Calculate Average Packet Size

```bash
$ jq '[.[] | .raw_packet_size] | add / length' logs/stream_analysis.json
1502.5
```

### Total Bytes Captured

```bash
$ jq '[.[] | .raw_packet_size] | add' logs/stream_analysis.json
785400
```

### Calculate Bitrate

```bash
# 785400 bytes * 8 bits/byte / 30 seconds / 1000 = kbps
# = 209.44 kbps
```

### Check for Jitter

```bash
$ jq '[.[] | .timestamp_deviation_ms] | max' logs/stream_analysis.json
0

$ jq '[.[] | .timestamp_deviation_ms] | min' logs/stream_analysis.json
0

$ jq '.[] | select(.timestamp_deviation_ms != 0)' logs/stream_analysis.json
# (no output = no jitter detected)
```

### Check Marker Bits (Frame Boundaries)

```bash
$ jq '.[] | select(.marker_bit == 1)' logs/stream_analysis.json | wc -l
87
# 87 frames captured (marker bit indicates end of frame)
```

### Check for Sequence Number Gaps (Packet Loss)

```bash
$ jq '.[] | .sequence_number' logs/stream_analysis.json | sort -n
12345
12346
12347
12348
...
12867
# No gaps = no packet loss
```

## Raw Stream File

File: `streams/raw_stream.bin`

- **Size**: 785,400 bytes
- **Format**: Binary RTP packets
- **Use**: Forensic analysis, replay, integration with other tools

Can be analyzed with:
- Wireshark
- tcpdump
- Custom analysis tools
- ffmpeg (for video extraction)

## Performance Metrics

```
Capture Duration:     30.02 seconds
Total Packets:        523 packets
Packet Rate:          17.42 packets/second
Average Packet Size:  1502.5 bytes
Total Data:           785,400 bytes
Bitrate:              209.44 kbps
Frames:               87 frames
Jitter:               0 ms (perfect timing)
Packet Loss:          0 packets (0%)
```

## Stream Quality Assessment

```
✅ Codec:              H264 (standard video codec)
✅ Packet Rate:        Consistent (17.42 pkt/s)
✅ Packet Size:        Consistent (1450-1500 bytes)
✅ Jitter:             None detected (0 ms deviation)
✅ Packet Loss:        None detected (no gaps)
✅ Frame Rate:         ~2.9 fps (87 frames / 30 sec)
✅ Bitrate:            209.44 kbps (reasonable for H264)
✅ Stream Quality:     EXCELLENT
```

## What Each Field Means

### packet_number: 1
- This is the 1st packet captured

### wallclock_time_ms: 1699000000123
- System time when packet was received
- 1699000000123 milliseconds since epoch
- Useful for correlating with system events

### packet_type: "H264"
- Video codec is H.264
- Standard video compression format

### payload_type_code: 96
- RTP payload type code for H264
- Dynamic payload type (96-127 range)

### raw_packet_size: 1500
- Total packet size is 1500 bytes
- Includes RTP header (12 bytes) + payload (1488 bytes)

### stream_timestamp: 1000000
- RTP timestamp from the camera
- Increments based on media clock (not wall clock)
- Used to detect jitter

### sequence_number: 12345
- RTP sequence number
- Increments by 1 for each packet
- Used to detect packet loss

### marker_bit: 0
- 0 = Not the last packet of a frame
- 1 = Last packet of a frame (frame boundary)

### ssrc: 3735928559
- Synchronization Source identifier
- Identifies the stream source
- Stays constant for entire stream

### timestamp_deviation_ms: 0
- Deviation from expected timestamp increment
- 0 = Perfect timing (no jitter)
- Positive = Timestamp jumped (possible frame drop)
- Negative = Timestamp increment smaller than expected

## Typical Thingino Camera Stream

Based on typical Thingino camera specifications:

```
Expected Codec:       H264
Expected Bitrate:     500-2000 kbps
Expected Frame Rate:  15-30 fps
Expected Packet Rate: 50-500 pkt/s
Expected Jitter:      0-5 ms
Expected Packet Loss: 0% (on stable network)
```

## Files Generated

After running the capture:

```
logs/
  └── stream_analysis.json          (JSON format analysis)
  
streams/
  └── raw_stream.bin                (Raw RTP packets)
```

## Next Steps

1. **Analyze the JSON** - Use jq to extract insights
2. **Check for issues** - Look for jitter, packet loss
3. **Calculate metrics** - Bitrate, frame rate, etc.
4. **Export to CSV** - For spreadsheet analysis
5. **Replay raw stream** - For forensic investigation

---

**This is what you'll see when you run Streamripper against your camera!**

