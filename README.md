# AmbiGlass — macOS/iPadOS (Liquid Glass)

Professional ambisonic capture and processing app for 4‑channel Ambi‑Alice microphones. Features real-time A→B conversion, IR measurement, loopback calibration, and multi-format export.

## Features

- ✅ **4-Channel Capture**: Real-time recording from Ambi‑Alice with peak meters
- ✅ **A→B Conversion**: Real-time ambisonic conversion with mic profile support
- ✅ **Orientation Control**: Yaw/pitch/roll rotation for FOA channels
- ✅ **Calibration System**: Loopback latency & gain measurement with auto-apply
- ✅ **IR Measurement**: Exponential sine sweep (ESS) with deconvolution
- ✅ **Multi-Format Export**: AmbiX, FuMa, Stereo, 5.1, 7.1, Binaural
- ✅ **Mic Calibration**: Frequency response curve loading and preview
- ✅ **High-Contrast Mode**: Accessibility support with theme customization

## Quick Start

### Setting Up Xcode Project

1. **Verify Files**: Run `./Scripts/setup_xcode.sh` to verify all files are present
2. **Create Project**: Open Xcode → New → Project → Multiplatform App → Name: **AmbiGlass**
3. **Follow Guide**: See **[Xcode Setup Guide](DOCS/XCODE_SETUP.md)** for detailed step-by-step instructions
4. **Add Files**: Add all source files from this repo to your Xcode project
5. **Build & Run**: Connect a 4+ channel audio interface and test

### First Use

1. **Run Calibration**: Go to Calibrate tab → Run Loopback Test
2. **Load Mic Profile**: Settings tab → Load mic profile from `Resources/Presets/AmbiAlice_v1.json`
3. **Start Recording**: Record tab → Select device → Press Record

## Documentation

- **[Xcode Setup Guide](DOCS/XCODE_SETUP.md)**: Step-by-step Xcode project integration ⭐ **START HERE**
- **[Architecture](DOCS/ARCHITECTURE.md)**: Module structure and data flow
- **[DSP Notes](DOCS/DSP_NOTES.md)**: A→B conversion, ESS, calibration algorithms
- **[IR Guide](DOCS/IR_GUIDE.md)**: Impulse response measurement workflow
- **[Formats](DOCS/FORMATS.md)**: Channel mappings for AmbiX, FuMa, and other formats
- **[Calibration](DOCS/CALIBRATION.md)**: Interface loopback and mic calibration
- **[Mic Profiles](DOCS/MIC_PROFILES.md)**: Profile format and matrix configuration
- **[UI Guide](DOCS/UI_GUIDE.md)**: User interface overview
- **[Test Plan](DOCS/TEST_PLAN.md)**: Testing strategy and acceptance criteria

## Usage Guide

### Recording

1. **Select Input Device**: Choose your 4+ channel interface in the Record tab
2. **Configure Safety**: Toggle "Safety A‑format" to save raw A‑format alongside B‑format
3. **Start Recording**: Press Record to begin capture
4. **Monitor Levels**: Watch the 4-channel peak meters (cyan→purple gradient)

### Calibration

1. **Loopback Setup**: Connect an output to an input with a short cable
2. **Run Test**: Press "Run Loopback Test" in the Calibrate tab
3. **Auto-Apply**: Calibration profile is automatically applied to future recordings
4. **View Results**: Check latency (ms) and per-channel gain offsets (dB)

### IR Measurement

1. **Configure Sweep**: Set length (8–30s) and frequency range (20–20,000 Hz typical)
2. **Select Outputs**: Choose which channels to route the sweep to
3. **Measure**: Press "Generate Sweep & Measure" to capture IR
4. **Export**: Choose format (Mono, Stereo, True-Stereo, FOA)

### Transcoding

1. **Drop Files**: Drag 4 mono WAV files (A‑format) into the Transcode tab
2. **Select Format**: Choose export format:
   - **AmbiX**: B‑format (W,Y,Z,X) ACN/SN3D
   - **FuMa**: B‑format (W,X,Y,Z) with FuMa scaling
   - **Stereo**: Simple L/R decode
   - **5.1/7.1**: Surround decode from FOA
   - **Binaural**: HRTF-based stereo (placeholder)

### Settings

- **High Contrast**: Enable for improved visibility
- **Mic Calibration**: Load frequency response curve (.txt/.csv)
- **Calibration Preview**: View loaded curve with frequency/gain stats

## Project Structure

```
AmbiGlass_starter/
├── App/              # SwiftUI app entry point
├── Audio/            # Core Audio capture & device management
├── DSP/              # Ambisonic processing, IR, calibration
├── Transcode/        # Format conversion and export
├── UI/               # Feature views (Record, IR, Transcode, etc.)
├── Theme/            # Liquid Glass UI components
├── Resources/        # Mic profiles and presets
├── Tests/            # Unit tests for DSP functions
├── Scripts/          # Build and format scripts
└── DOCS/             # Comprehensive documentation
```

## Development

### Building

```bash
# Build with Xcode
xcodebuild -scheme AmbiGlass -configuration Debug build

# Format code
./Scripts/format.sh

# Run tests (requires Xcode project)
./Scripts/test.sh
```

### Testing

Unit tests are located in `/Tests`:
- **AmbisonicsDSPTests**: A→B mapping and orientation transforms
- **IRDeconvolutionTests**: ESS deconvolution with known IRs
- **CalibrationTests**: Latency and gain estimation

### CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on push/PR:
- Build verification
- Swift format checking

## Status

- ✅ Capture + meters
- ✅ Real-time A→B conversion
- ✅ AmbiX/FuMa export
- ✅ ESS deconvolution with windowing
- ✅ Loopback calibration
- ✅ Multi-format transcoding
- ✅ Mic calibration preview
- ✅ High-contrast accessibility
- ✅ Progress indicators

## Requirements

- macOS 14+ / iPadOS 17+
- Xcode 15+
- 4+ channel audio interface (for capture)
- Swift 5.9+

## License

See [LICENSE](LICENSE) file.

## Contributing

See [CONTRIBUTING.md](DOCS/CONTRIBUTING.md) for development guidelines.
