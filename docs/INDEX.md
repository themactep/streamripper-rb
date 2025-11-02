# Streamripper - Complete File Index

## 📋 Project Overview

A comprehensive Ruby CLI application for capturing, analyzing, and logging RTSP streams from IP cameras with forensic capabilities.

## 📁 Directory Structure

```
streamripper-rb/
├── bin/                          # Executable
├── lib/streamripper/             # Core library modules
├── spec/                         # Test suite
├── docs/                         # Technical documentation
├── examples/                     # Configuration and usage examples
├── Configuration files           # Gemfile, Rakefile, etc.
└── Documentation files           # README, guides, etc.
```

## 📄 All Project Files

### 🚀 Executable
- **bin/streamripper** - Main CLI executable

### 📚 Core Library (lib/streamripper/)
- **streamripper.rb** - Main module loader
- **version.rb** - Version information (0.1.0)
- **rtsp_fetcher.rb** - RTSP protocol handler (200+ lines)
- **packet_analyzer.rb** - Packet parsing and analysis (150+ lines)
- **packet_logger.rb** - JSON/CSV logging (100+ lines)
- **stream_saver.rb** - Raw stream capture (50+ lines)
- **cli.rb** - Command-line interface (150+ lines)

### 🧪 Test Suite (spec/)
- **spec_helper.rb** - RSpec configuration
- **packet_analyzer_spec.rb** - PacketAnalyzer tests (80+ lines)
- **packet_logger_spec.rb** - PacketLogger tests (100+ lines)
- **stream_saver_spec.rb** - StreamSaver tests (100+ lines)

### 📖 User Documentation
- **README.md** - Complete user guide and feature overview
- **QUICK_START.md** - 5-minute quick start guide
- **SETUP.md** - Installation instructions for all platforms
- **PROJECT_SUMMARY.md** - Comprehensive project overview
- **DELIVERABLES.md** - Complete deliverables list

### 🔧 Technical Documentation
- **docs/PACKET_ANALYSIS.md** - Detailed packet format and analysis
- **docs/TROUBLESHOOTING.md** - Troubleshooting guide and solutions

### 📝 Examples
- **examples/config.yml** - Configuration example
- **examples/usage_examples.sh** - 10 usage examples

### ⚙️ Configuration & Build
- **Gemfile** - Ruby dependencies
- **streamripper.gemspec** - Gem package specification
- **Rakefile** - Build and test tasks
- **.gitignore** - Git ignore rules

### 📑 This File
- **INDEX.md** - This file (complete file index)

## 🎯 Quick Navigation

### For Users
1. Start here: **QUICK_START.md** (5 minutes)
2. Full guide: **README.md**
3. Installation: **SETUP.md**
4. Examples: **examples/usage_examples.sh**
5. Troubleshooting: **docs/TROUBLESHOOTING.md**

### For Developers
1. Overview: **PROJECT_SUMMARY.md**
2. Architecture: **lib/streamripper/*.rb**
3. Tests: **spec/*_spec.rb**
4. Technical: **docs/PACKET_ANALYSIS.md**

### For Deployment
1. Installation: **SETUP.md**
2. Configuration: **examples/config.yml**
3. Build: **Rakefile**
4. Package: **streamripper.gemspec**

## 📊 File Statistics

| Category | Count | Files |
|----------|-------|-------|
| Executables | 1 | bin/streamripper |
| Core Modules | 7 | lib/streamripper/*.rb |
| Tests | 4 | spec/*_spec.rb |
| Documentation | 5 | *.md, docs/*.md |
| Examples | 2 | examples/* |
| Config | 4 | Gemfile, Rakefile, .gitignore, *.gemspec |
| **Total** | **23** | **All files** |

## 🔍 Module Overview

### RTSPFetcher (rtsp_fetcher.rb)
- RTSP protocol communication
- TCP socket management
- RTP packet reading
- RTSP handshake handling

### PacketAnalyzer (packet_analyzer.rb)
- RTP header parsing
- Payload type identification
- Timestamp deviation calculation
- Statistics tracking

### PacketLogger (packet_logger.rb)
- JSON format logging
- CSV format logging
- Dual format support
- File I/O management

### StreamSaver (stream_saver.rb)
- Raw packet saving
- Binary file output
- Directory creation
- Statistics tracking

### CLI (cli.rb)
- Command-line interface
- Argument parsing
- Progress reporting
- Summary statistics

## 🎓 Learning Path

### Beginner
1. Read QUICK_START.md
2. Run basic capture
3. Examine JSON output
4. Read README.md

### Intermediate
1. Try different output formats
2. Analyze captured data
3. Read PACKET_ANALYSIS.md
4. Explore examples/

### Advanced
1. Study source code (lib/streamripper/)
2. Run and modify tests (spec/)
3. Extend functionality
4. Integrate with other tools

## 🚀 Getting Started

```bash
# 1. Install
cd streamripper-rb
bundle install
chmod +x bin/streamripper

# 2. Test
bundle exec rspec

# 3. Capture
./bin/streamripper capture rtsp://camera-ip:554/stream

# 4. Analyze
jq '.' logs/stream_analysis.json
```

## 📋 Feature Checklist

- ✅ RTSP stream fetching
- ✅ RTP packet parsing
- ✅ Packet analysis and logging
- ✅ JSON output format
- ✅ CSV output format
- ✅ Raw stream capture
- ✅ Timestamp deviation tracking
- ✅ CLI interface
- ✅ Comprehensive tests
- ✅ Complete documentation
- ✅ Usage examples
- ✅ Troubleshooting guide

## 🔗 File Dependencies

```
bin/streamripper
  └── lib/streamripper.rb
      ├── lib/streamripper/version.rb
      ├── lib/streamripper/rtsp_fetcher.rb
      ├── lib/streamripper/packet_analyzer.rb
      ├── lib/streamripper/packet_logger.rb
      ├── lib/streamripper/stream_saver.rb
      └── lib/streamripper/cli.rb

spec/*_spec.rb
  └── spec/spec_helper.rb
      └── lib/streamripper.rb
```

## 📦 Dependencies

### Runtime
- thor (~1.2) - CLI framework
- json (~2.6) - JSON handling

### Development
- rspec (~3.12) - Testing
- rspec-mocks (~3.12) - Mocking
- pry (~0.14) - Debugging
- rubocop (~1.40) - Linting

## 🎯 Use Cases

1. **Stream Quality Monitoring** - Detect jitter and frame drops
2. **Forensic Analysis** - Investigate stream issues
3. **Bandwidth Analysis** - Calculate bitrate and utilization
4. **Network Troubleshooting** - Identify packet loss
5. **Integration** - Feed data to other tools

## 📞 Support

- **Quick Help**: `./bin/streamripper capture --help`
- **Quick Start**: Read QUICK_START.md
- **Full Guide**: Read README.md
- **Issues**: See docs/TROUBLESHOOTING.md
- **Technical**: See docs/PACKET_ANALYSIS.md

## 📝 Version

**Streamripper v0.1.0** - Initial Release

## 👤 Author

Paul Philippov (themactep@gmail.com)

## 📄 License

MIT License

---

**Last Updated**: 2025-11-01
**Total Files**: 23
**Total Lines of Code**: ~1500
**Test Coverage**: 15+ test cases

