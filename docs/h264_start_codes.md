# H.264 Start Code Format - Critical Finding

## Problem Statement

During MP4 video generation, the system was experiencing H.264 decoding errors:
```
[h264] error while decoding MB 74 58, bytestream -7
[h264] concealing 1175 DC, 1175 AC, 1175 MV errors in P frame
```

The MP4 files would play but with significant corruption and decoding errors.

## Root Cause Analysis

### Investigation Process

1. **Extracted frames from MP4** using ffmpeg's h264_mp4toannexb bitstream filter
2. **Compared extracted H.264** with original H.264 stream using `cmp -l`
3. **Found byte-level differences** at position 55 (0x37)

### The Discovery

**Original H.264 stream:**
```
00 00 00 01 28 ee 3c b0 00 00 00 01 25 b8...
```

**Extracted from MP4:**
```
00 00 00 01 28 ee 3c b0 00 00 01 25 b8...
```

**Difference:** The second start code was converted from 4-byte (`00 00 00 01`) to 3-byte (`00 00 01`)!

## Root Cause

**MP4 containers use 3-byte start codes internally**, not 4-byte start codes.

When ffmpeg creates an MP4 from H.264:
1. It converts 4-byte start codes to 3-byte start codes
2. Stores them in the MP4 container
3. When extracting back, we get 3-byte start codes

Our system was using 4-byte start codes, causing:
- Stream misalignment when creating MP4
- Corruption when extracting from MP4
- Decoding errors in the final output

## Solution

**Use 3-byte start codes (`0x00 0x00 0x01`) instead of 4-byte start codes (`0x00 0x00 0x00 0x01`)**

### Code Changes

In `lib/streamripper/web_server.rb`:

**Before (4-byte start codes):**
```ruby
current_nal = "\x00\x00\x00\x01" + nal_header + fragment_data
result += "\x00\x00\x00\x01" + payload
```

**After (3-byte start codes):**
```ruby
current_nal = "\x00\x00\x01" + nal_header + fragment_data
result += "\x00\x00\x01" + payload
```

## Results

### Before Fix
- ❌ Multiple decoding errors per video
- ❌ Corrupted frames
- ❌ Unreliable playback

### After Fix
- ✅ **0 decode errors**
- ✅ Perfect H.264 streams
- ✅ Clean MP4 playback
- ✅ Professional quality output

### Verification

```
[in#0/h264] 36 packets read (266495 bytes); 36 frames decoded; 0 decode errors
```

## Technical Details

### H.264 Start Code Formats

| Format | Bytes | Usage |
|--------|-------|-------|
| 4-byte | `00 00 00 01` | File format, raw H.264 files |
| 3-byte | `00 00 01` | MP4 containers, streaming |

### Why MP4 Uses 3-byte Start Codes

MP4 containers store NAL unit length explicitly in the box structure, so the 4th byte of the start code is redundant. Using 3-byte start codes saves space and is the standard for MP4 muxing.

## Lessons Learned

1. **Start code format matters** - Different containers use different formats
2. **Test round-trip conversion** - Extract from MP4 and compare with original
3. **Use ffmpeg's bitstream filters** - `h264_mp4toannexb` reveals format differences
4. **Byte-level comparison is essential** - High-level testing missed this issue

## References

- H.264 Specification: ITU-T H.264
- MP4 Specification: ISO/IEC 14496-12
- FFmpeg h264_mp4toannexb: Converts MP4 format to Annex B format

