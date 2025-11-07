# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of AmbiGlass
- 4-channel audio capture from Ambi-Alice microphones
- Real-time A→B format conversion (AmbiX/FuMa)
- Yaw/pitch/roll orientation control for FOA channels
- Loopback calibration system for latency and gain measurement
- Exponential Sine Sweep (ESS) IR measurement
- Multi-format export: AmbiX, FuMa, Stereo, 5.1, 7.1, Binaural
- Mic calibration curve loading and preview
- High-contrast accessibility mode
- Liquid Glass UI theme
- Comprehensive documentation

### Technical Details
- SwiftUI-based macOS/iPadOS app
- Core Audio / AVAudioEngine for audio capture
- vDSP for DSP operations
- FFT-based IR deconvolution
- Cross-correlation for latency measurement
- JSON-based mic profile format

## [0.1.0] - 2025-11-07

### Added
- Initial project structure
- Source code for all core features
- Unit tests for DSP functions
- Build and format scripts
- Comprehensive documentation

[Unreleased]: https://github.com/athompson36/ambi-glass/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/athompson36/ambi-glass/releases/tag/v0.1.0

