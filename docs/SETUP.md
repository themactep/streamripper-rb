# Setup Guide for Streamripper

## Prerequisites

### System Requirements

- Ruby 2.7 or higher
- Bundler (Ruby package manager)
- Linux/macOS/Windows with network access to RTSP cameras

### Installation Steps

#### 1. Install Ruby

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install ruby-full ruby-dev build-essential
```

**macOS (using Homebrew):**
```bash
brew install ruby
```

**Windows:**
Download and install from https://rubyinstaller.org/

#### 2. Install Bundler

```bash
gem install bundler
```

#### 3. Clone and Setup Streamripper

```bash
git clone <repository-url> streamripper-rb
cd streamripper-rb
bundle install
chmod +x bin/streamripper
```

## Verification

Test the installation:

```bash
./bin/streamripper --version
```

Run the test suite:

```bash
bundle exec rspec
```

## Troubleshooting

### Bundle Install Fails

If you encounter issues with gem installation:

```bash
# Update bundler
gem update bundler

# Clear bundler cache
bundle cache --no-prune

# Try install again
bundle install --verbose
```

### RTSP Connection Issues

- Verify camera is accessible: `ping <camera-ip>`
- Check RTSP URL format: `rtsp://username:password@camera-ip:554/stream`
- Ensure firewall allows port 554 (RTSP)
- Test with VLC: `vlc rtsp://camera-ip:554/stream`

### Permission Denied

If you get permission errors:

```bash
chmod +x bin/streamripper
```

## Next Steps

See README.md for usage instructions.

