# AmbiIRverb Plugin Integration

**Updated:** 2025-11-11

This document describes the integration of the AmbiIRverb plugin into the AmbiGlass project.

## Overview

AmbiIRverb is a hybrid convolution + algorithmic reverb plugin built with JUCE 8. It provides:
- True-stereo convolution (mono/stereo/4-ch true-stereo IR support)
- Algorithmic reverb engines: Spring, Plate, Room, Hall
- Shared controls: Time, Width, Depth, Diffusion, Mod Depth/Rate
- Pre HP/LP filters, Output Parametric EQ (3-band), Dry/Wet mix
- Preset save/load (`.ambipreset` JSON format)
- Liquid Glass UI styling

## Project Structure

The AmbiIRverb plugin source code is located in `Plugins/AmbiIRverb/`:

```
Plugins/AmbiIRverb/
├── CMakeLists.txt          # CMake build configuration
├── Source/                 # C++ plugin source code
│   ├── ConvoEngine.*      # Convolution engine
│   ├── SpringEngine.*      # Spring reverb algorithm
│   ├── PlateEngine.*       # Plate reverb algorithm
│   ├── RoomEngine.*        # Room reverb algorithm
│   ├── HallEngine.*        # Hall reverb algorithm
│   ├── HybridVerb.*        # Main plugin processor
│   ├── PluginProcessor.*   # JUCE plugin processor
│   └── PluginEditor.*      # JUCE plugin UI
├── docs/                   # Comprehensive plugin documentation
│   ├── README.md           # Plugin overview and quick start
│   ├── ARCHITECTURE.md     # Plugin architecture
│   ├── BUILD.md            # Build instructions
│   ├── DSP_DESIGN.md       # DSP algorithm design
│   ├── CURRENT_STATE.md    # Development status
│   ├── DEVELOPMENT_ROADMAP.md  # Development plan
│   └── IMPLEMENTATION_GUIDE.md # Implementation details
├── Presets/                # Example presets (also in Resources/Presets/)
└── tests/                  # Plugin tests
```

## SwiftUI Integration

The AmbiGlass app includes SwiftUI components for testing impulse responses:

### IRTestView
Location: `UI/IRTestView.swift`

A SwiftUI view that provides:
- IR file loading interface
- Real-time wet/dry mix control
- I/O latency monitoring
- Start/Stop controls

### IRTestHost
Location: `UI/IRTestHost.swift`

An AVAudioEngine-based host that:
- Loads impulse response files
- Applies convolution in real-time
- Manages audio I/O routing
- Provides latency measurements

**Usage Example:**
```swift
let host = IRTestHost()
try host.loadIR(from: irURL)
try host.start()
host.wetDryMix = 50.0  // 50% wet
```

## Presets

AmbiIRverb presets are stored in `.ambipreset` format (JSON). Preset files are located in:
- `Resources/Presets/` (integrated with AmbiGlass presets)
- `Plugins/AmbiIRverb/Presets/` (original plugin location)

**Included Presets:**
- `Hall_Hall_Cinematic_Long.ambipreset`
- `Plate_Plate_Vocal_Shine.ambipreset`
- `Room_Room_Tight_Booth.ambipreset`
- `Spring_Spring_Indie_Slap.ambipreset`
- `IR_Neutral_1x.ambipreset`

## Building the Plugin

The plugin is built separately from the AmbiGlass Swift app using CMake and JUCE.

### Prerequisites
- CMake 3.22+
- C++20 toolchain (Xcode 14+ / Visual Studio 2022+)
- JUCE 8+ (auto-fetched via CMake or submodule)

### Build Steps

**macOS:**
```bash
cd Plugins/AmbiIRverb
cmake -B build -G "Xcode"
cmake --build build --config Release
```

**Windows:**
```bash
cd Plugins/AmbiIRverb
cmake -B build -G "Visual Studio 17 2022"
cmake --build build --config Release
```

The built plugins will be installed to:
- **macOS**: 
  - AU: `~/Library/Audio/Plug-Ins/Components/`
  - VST3: `~/Library/Audio/Plug-Ins/VST3/`
- **Windows**: User VST3 directory

For detailed build instructions, see `Plugins/AmbiIRverb/docs/BUILD.md`.

## Plugin Status

**Current Status:** ~25% complete (as of plugin integration)

- ✅ Core infrastructure (ConvoEngine, Parameters, FileIO)
- ✅ Plugin framework (Processor, Editor, LookAndFeel)
- ⚠️ Algorithmic engines are stubs (Spring, Plate, Room, Hall)
- ⚠️ Preset system partially implemented
- ✅ Documentation complete

**Development Roadmap:** See `Plugins/AmbiIRverb/docs/DEVELOPMENT_ROADMAP.md` for detailed development phases and timeline (estimated 3-4 months to v1.0).

## Integration Notes

1. **Standalone vs Plugin**: The SwiftUI app uses `IRTestView`/`IRTestHost` for IR audition, which uses Core Audio's `AVAudioUnitConvolution`. This is separate from the JUCE plugin, which can be built and used in DAWs.

2. **Preset Compatibility**: The `.ambipreset` format is designed for the JUCE plugin. The SwiftUI IR test view uses standard audio file formats (WAV, AIFF) for IRs.

3. **Future Integration**: Potential future work could include:
   - Direct plugin integration into AmbiGlass app (requires JUCE framework embedding)
   - Preset format conversion between plugin and app
   - Shared IR library management

## Documentation

For detailed plugin documentation, see:
- **Quick Start**: `Plugins/AmbiIRverb/docs/README.md`
- **Architecture**: `Plugins/AmbiIRverb/docs/ARCHITECTURE.md`
- **Build Instructions**: `Plugins/AmbiIRverb/docs/BUILD.md`
- **DSP Design**: `Plugins/AmbiIRverb/docs/DSP_DESIGN.md`
- **Current State**: `Plugins/AmbiIRverb/docs/CURRENT_STATE.md`
- **Development Roadmap**: `Plugins/AmbiIRverb/docs/DEVELOPMENT_ROADMAP.md`
- **Implementation Guide**: `Plugins/AmbiIRverb/docs/IMPLEMENTATION_GUIDE.md`

## License

The AmbiIRverb plugin is licensed under MIT (see `Plugins/AmbiIRverb/LICENSE`).

