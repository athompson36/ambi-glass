# AmbiGlass — Feature Summary

**Professional Ambisonic Capture & Processing Application**

---

## Overview

AmbiGlass is a professional-grade macOS/iPadOS application designed for 4-channel Ambi-Alice microphone capture, real-time ambisonic conversion, impulse response measurement, and multi-format audio export. Built with SwiftUI and optimized for audio professionals, it provides a complete workflow for ambisonic recording and processing.

---

## Core Features

### 1. Multi-Channel Audio Capture

**Real-Time Recording**
- 4-channel simultaneous capture from Ambi-Alice microphones
- Support for 4+ channel audio interfaces
- Real-time peak metering for all channels
- Visual feedback with cyan-to-purple gradient meters
- Safety A-format recording option

**Device Management**
- Automatic device enumeration
- macOS: Full device list with AVCaptureDevice
- iPadOS: AVAudioSession device selection
- Real-time device switching
- Channel count validation

**Recording Options**
- Configurable sample rates (default: 48kHz)
- Adjustable buffer sizes
- Safety A-format toggle (saves raw A-format alongside B-format)
- Automatic file naming with timestamps

---

### 2. Real-Time Ambisonic Conversion

**A→B Format Conversion**
- Real-time A-format to FOA B-format conversion
- Matrix-based transformation with mic profile support
- Energy-preserving algorithms
- Low-latency processing optimized with Accelerate framework

**Mic Profile Support**
- Load custom 4×4 conversion matrices
- JSON-based profile format
- Default profiles included (AmbiAlice_v1)
- Per-capsule trim adjustments
- Frequency response calibration curves

**Orientation Control**
- Yaw/pitch/roll rotation transforms
- Real-time orientation adjustment
- Euler angle rotation (ZYX order)
- Preserves omnidirectional (W) channel

**Gain Compensation**
- Per-capsule trim application
- Interface channel gain offsets
- Mic calibration curve interpolation
- Automatic gain compensation during recording

---

### 3. Calibration System

**Loopback Calibration**
- Automatic I/O latency measurement
- Cross-correlation-based delay estimation
- Per-channel gain offset calculation
- Frequency response analysis (optional)

**Profile Management**
- InterfaceProfile persistence
- Automatic profile application
- Device-specific calibration storage
- Timestamp-based profile versioning

**Calibration Workflow**
- Simple one-button calibration
- Visual progress indicators
- Results display (latency, gains)
- Auto-apply to future recordings

---

### 4. Impulse Response Measurement

**Exponential Sine Sweep (ESS)**
- Configurable sweep length (2-30 seconds)
- Adjustable frequency range (20-20,000 Hz typical)
- High-quality sweep generation
- Inverse filter calculation

**Deconvolution Processing**
- FFT-based deconvolution
- Peak detection and alignment
- Windowing and normalization
- Exponential decay windowing
- Noise reduction

**IR Export Formats**
- Mono IR (single channel)
- Stereo IR (2-channel)
- True-stereo IR (4-channel A-format)
- FOA IR (B-format, AmbiX W,Y,Z,X)

**Output Routing**
- Multi-channel output selection
- Configurable output routing
- Support for 1-8 output channels
- Visual channel selection interface

---

### 5. Multi-Format Export

**Ambisonic Formats**
- **AmbiX**: B-format (W,Y,Z,X) ACN/SN3D normalization
- **FuMa**: B-format (W,X,Y,Z) with FuMa scaling
- Proper channel ordering and normalization

**Surround Formats**
- **Stereo**: Simple L/R decode from FOA
- **5.1**: 6-channel surround (L, R, C, LFE, Ls, Rs)
- **7.1**: 8-channel surround (adds Lb, Rb)
- FOA-based decoding algorithms

**Binaural Export**
- Placeholder for HRTF-based binaural rendering
- Future: SOFA file support
- Future: Real-time binaural preview

**Batch Processing**
- Drag & drop 4 mono WAV files
- Automatic file validation
- Error handling and user feedback
- Multiple export format support

---

### 6. User Interface

**Liquid Glass Theme**
- Modern glassmorphism design
- Dark theme optimized for audio work
- High-contrast accessibility mode
- Customizable visual elements

**Main Views**
- **Record**: Device selection, recording controls, meters
- **Measure IR**: Sweep configuration, IR measurement, export
- **Transcode**: Drag & drop, format selection, batch export
- **Calibrate**: Loopback test, profile management
- **Settings**: Preferences, mic calibration, theme options

**User Experience**
- Progress indicators for long operations
- Real-time status updates
- Error messages and user feedback
- Intuitive tab-based navigation

**Accessibility**
- High-contrast mode
- Keyboard navigation support
- VoiceOver compatibility
- Adjustable UI elements

---

### 7. Mic Calibration

**Frequency Response Loading**
- Support for .txt, .csv, .cal files
- Automatic frequency/gain parsing
- Log-frequency interpolation
- Visual curve preview

**Calibration Preview**
- Interactive frequency response graph
- Log-frequency axis display
- Gain range visualization
- Statistics display (range, points, gain)

**Application**
- Automatic calibration application
- Frequency-dependent gain correction
- Smooth interpolation between points
- Optional per-capsule calibration

---

### 8. Advanced Features

**Profile System**
- MicProfile: Matrix, orientation, trims
- InterfaceProfile: Latency, gains, device info
- Persistent storage in Application Support
- JSON-based format

**Error Handling**
- Comprehensive error checking
- User-friendly error messages
- Graceful degradation
- File I/O error handling

**Performance**
- Optimized with Accelerate framework
- Real-time processing capability
- Efficient memory management
- Low-latency audio pipeline

---

## Technical Specifications

### Platform Support
- **macOS**: 14.0+ (Sonoma and later)
- **iPadOS**: 17.0+ (iOS 17 and later)
- Universal binary support

### Audio Specifications
- **Sample Rates**: 44.1kHz, 48kHz, 96kHz (configurable)
- **Bit Depth**: 32-bit float (internal), 16/24/32-bit export
- **Channels**: 4-channel input (minimum), multi-channel output
- **Formats**: WAV (PCM), interleaved and non-interleaved

### Processing
- **DSP Framework**: Accelerate (vDSP, FFT)
- **Audio Framework**: AVFoundation, AVAudioEngine
- **UI Framework**: SwiftUI
- **Language**: Swift 5.9+

### File Formats
- **Input**: Mono WAV files (4-channel A-format)
- **Output**: WAV (AmbiX, FuMa, Stereo, 5.1, 7.1, Binaural)
- **Profiles**: JSON (mic profiles, interface profiles)
- **Calibration**: Text/CSV (frequency response curves)

---

## Use Cases

### Professional Audio Production
- Ambisonic field recording
- Spatial audio capture
- 360° audio production
- VR/AR audio content creation

### Acoustic Measurement
- Room impulse response measurement
- Acoustic analysis
- Reverb time measurement
- Frequency response analysis

### Post-Production
- Ambisonic format conversion
- Surround sound mixing
- Binaural rendering preparation
- Multi-format distribution

### Research & Development
- Ambisonic algorithm testing
- Acoustic research
- Audio format development
- Spatial audio experimentation

---

## Workflow Examples

### Recording Session
1. Connect 4-channel audio interface
2. Run loopback calibration
3. Load mic profile
4. Configure recording settings
5. Start recording with real-time A→B conversion
6. Monitor levels with peak meters
7. Stop and review files

### IR Measurement
1. Connect output to loudspeaker
2. Connect input (mic or interface)
3. Configure sweep parameters
4. Select output channels
5. Generate sweep and measure
6. Review deconvolved IR
7. Export in desired format

### Format Conversion
1. Drag 4 mono WAV files (A-format)
2. Select export format
3. Process and export
4. Verify output files

---

## Performance Characteristics

### Latency
- **Recording Latency**: < 10ms (typical)
- **Processing Latency**: < 1ms (A→B conversion)
- **Calibration Accuracy**: ±1ms latency measurement

### Throughput
- **Real-Time Processing**: Up to 192kHz sample rate
- **Batch Export**: Multiple files in parallel
- **IR Deconvolution**: Optimized FFT processing

### Resource Usage
- **CPU**: Optimized for efficiency
- **Memory**: Efficient buffer management
- **Disk**: Configurable file locations

---

## Quality Assurance

### Testing
- Unit tests for DSP functions
- Integration tests for audio pipeline
- Calibration accuracy tests
- Format conversion validation

### Validation
- Energy preservation verification
- Channel ordering validation
- Format compliance checking
- File integrity verification

---

## Future Roadmap

### Planned Features
- Real-time binaural monitoring
- SOFA HRTF file support
- Advanced IR windowing options
- Batch processing improvements
- Preset management UI
- Export history tracking

### Enhancements
- Performance optimizations
- Additional export formats
- Advanced calibration options
- Cloud sync capabilities
- Plugin support

---

## Support & Documentation

### Documentation
- Comprehensive user guides
- Technical documentation
- API reference
- Video tutorials (planned)

### Resources
- Example mic profiles
- Calibration templates
- Workflow guides
- Best practices

---

## System Requirements

### Minimum Requirements
- macOS 14.0+ or iPadOS 17.0+
- 4+ channel audio interface
- 2GB RAM
- 500MB disk space

### Recommended Requirements
- macOS 15.0+ or iPadOS 18.0+
- Professional audio interface
- 8GB+ RAM
- SSD storage

---

## Licensing

See LICENSE file for details.

---

**AmbiGlass** — Professional Ambisonic Capture & Processing

*Version 1.0 | November 2025*

