# 🚀 Streamripper - START HERE

Welcome to Streamripper! This is your entry point to the RTSP stream analysis tool.

## ⚡ Quick Start (5 Minutes)

### 1. Install Dependencies
```bash
cd streamripper-rb
gem install bundler
bundle install
chmod +x bin/streamripper
```

### 2. Verify Installation
```bash
bundle exec rspec
```

### 3. Capture Your First Stream
```bash
./bin/streamripper capture rtsp://192.168.1.100:554/stream
```

### 4. View Results
```bash
cat logs/stream_analysis.json | jq '.'
```

**Done!** You now have packet analysis logs and raw stream data.

## 📚 Documentation Map

### 👤 I'm a User
1. **QUICK_START.md** ← Start here (5 min read)
2. **README.md** ← Full user guide
3. **examples/usage_examples.sh** ← Copy-paste examples
4. **docs/TROUBLESHOOTING.md** ← If something breaks

### 👨‍💻 I'm a Developer
1. **PROJECT_SUMMARY.md** ← Architecture overview
2. **lib/streamripper/*.rb** ← Source code
3. **spec/*_spec.rb** ← Tests
4. **docs/PACKET_ANALYSIS.md** ← Technical details

### 🔧 I'm Installing
1. **SETUP.md** ← Installation guide
2. **Gemfile** ← Dependencies
3. **Rakefile** ← Build tasks

## 🎯 What This Tool Does

```
IP Camera (RTSP Stream)
        ↓
   Streamripper
        ↓
   ┌───┴───┐
   ↓       ↓
 JSON    Binary
 CSV     Raw Stream
   ↓       ↓
Analysis  Forensics
```

**Captures**: Every packet from your IP camera
**Analyzes**: Packet type, size, timestamp, jitter
**Logs**: JSON, CSV, or raw binary format
**Detects**: Frame drops, jitter, packet loss

## 💡 Common Tasks

### Capture for 60 Seconds
```bash
./bin/streamripper capture rtsp://camera-ip:554/stream --duration 60
```

### Save as CSV
```bash
./bin/streamripper capture rtsp://camera-ip:554/stream \
  --format csv \
  --output logs/analysis.csv
```

### With Authentication
```bash
./bin/streamripper capture rtsp://admin:password@camera-ip:554/stream
```

### Verbose Output
```bash
./bin/streamripper capture rtsp://camera-ip:554/stream --verbose
```

## 📊 Understanding the Output

### JSON Log Entry
```json
{
  "packet_number": 1,
  "wallclock_time_ms": 1699000000123,
  "packet_type": "H264",
  "raw_packet_size": 1500,
  "stream_timestamp": 1000000,
  "timestamp_deviation_ms": 0
}
```

**What it means:**
- Packet #1 received at 1699000000123 ms
- H264 video codec
- 1500 bytes in size
- No jitter (deviation = 0)

### Analyze the Data
```bash
# Count packets
jq 'length' logs/stream_analysis.json

# Find jitter
jq '.[] | select(.timestamp_deviation_ms != 0)' logs/stream_analysis.json

# Calculate bitrate
jq '[.[] | .raw_packet_size] | add' logs/stream_analysis.json
```

## 🔍 Troubleshooting

### "Connection refused"
```bash
# Check if camera is reachable
ping 192.168.1.100

# Check RTSP port
nc -zv 192.168.1.100 554

# Test with VLC
vlc rtsp://192.168.1.100:554/stream
```

### "No packets captured"
1. Verify stream works in VLC
2. Check firewall (port 554)
3. Try different RTSP URL
4. See docs/TROUBLESHOOTING.md

### "Permission denied"
```bash
chmod +x bin/streamripper
mkdir -p logs streams
```

## 📁 Project Files

```
bin/streamripper              ← The executable
lib/streamripper/
  ├── cli.rb                 ← Command-line interface
  ├── rtsp_fetcher.rb        ← RTSP connection
  ├── packet_analyzer.rb     ← Packet analysis
  ├── packet_logger.rb       ← Logging
  └── stream_saver.rb        ← Raw stream save
spec/                        ← Tests
docs/                        ← Documentation
examples/                    ← Examples
```

## 🎓 Learning Path

### Beginner (15 min)
1. Read this file
2. Run basic capture
3. Look at JSON output
4. Read QUICK_START.md

### Intermediate (1 hour)
1. Try different options
2. Analyze captured data
3. Read README.md
4. Check examples/

### Advanced (2+ hours)
1. Study source code
2. Run and modify tests
3. Read PACKET_ANALYSIS.md
4. Extend functionality

## 🚀 Next Steps

### Option 1: Quick Test
```bash
# Capture 10 packets from a test stream
./bin/streamripper capture rtsp://camera-ip:554/stream \
  --max-packets 10 \
  --verbose
```

### Option 2: Full Analysis
```bash
# Capture for 5 minutes with all details
./bin/streamripper capture rtsp://camera-ip:554/stream \
  --duration 300 \
  --format both \
  --verbose
```

### Option 3: Forensic Capture
```bash
# Capture raw stream for forensic analysis
./bin/streamripper capture rtsp://camera-ip:554/stream \
  --raw-stream streams/forensic_capture.bin \
  --duration 60
```

## 📖 Documentation Files

| File | Purpose | Read Time |
|------|---------|-----------|
| QUICK_START.md | Quick reference | 5 min |
| README.md | Full guide | 15 min |
| SETUP.md | Installation | 10 min |
| docs/PACKET_ANALYSIS.md | Technical details | 20 min |
| docs/TROUBLESHOOTING.md | Problem solving | 10 min |
| examples/usage_examples.sh | Copy-paste examples | 5 min |
| PROJECT_SUMMARY.md | Architecture | 15 min |

## ❓ FAQ

**Q: Do I need a real camera?**
A: Yes, you need an IP camera with RTSP support.

**Q: What cameras are supported?**
A: Any camera with RTSP streaming (Hikvision, Dahua, Axis, etc.)

**Q: Can I capture multiple cameras?**
A: Yes, run multiple instances or use a loop.

**Q: How much disk space do I need?**
A: Depends on duration and bitrate. ~100MB per minute typical.

**Q: Can I replay the raw stream?**
A: Yes, the raw_stream.bin file contains all packets.

**Q: Is this production-ready?**
A: Yes, fully tested and documented.

## 🎯 Common Camera URLs

```
Hikvision:  rtsp://admin:password@192.168.1.100:554/Streaming/Channels/101
Dahua:      rtsp://admin:password@192.168.1.100:554/stream/main
Axis:       rtsp://admin:password@192.168.1.100:554/axis-media/media.amp
Generic:    rtsp://192.168.1.100:554/stream
```

## 💬 Need Help?

1. **Quick questions**: See QUICK_START.md
2. **Installation issues**: See SETUP.md
3. **Usage questions**: See README.md
4. **Technical details**: See docs/PACKET_ANALYSIS.md
5. **Problems**: See docs/TROUBLESHOOTING.md

## 🎉 You're Ready!

You now have everything you need to:
- ✅ Capture RTSP streams
- ✅ Analyze packets
- ✅ Log data
- ✅ Detect issues
- ✅ Perform forensics

**Start capturing!**

```bash
./bin/streamripper capture rtsp://your-camera:554/stream
```

---

**Questions?** Check the documentation files above.
**Found a bug?** See docs/TROUBLESHOOTING.md
**Want to extend?** See PROJECT_SUMMARY.md

**Happy streaming! 🎬**

