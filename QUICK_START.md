# AmbiGlass Quick Start Checklist

Use this checklist to verify your Xcode project is set up correctly.

## ✅ Pre-Flight Checklist

### 1. Project Structure
- [ ] All folders created (App, Audio, DSP, Transcode, UI, Theme, Resources, Tests)
- [ ] All Swift files added to project
- [ ] All files have correct target membership (AmbiGlass)
- [ ] Test files added to test target (AmbiGlassTests)

### 2. Build Settings
- [ ] Deployment Target: macOS 14.0+ / iOS 17.0+
- [ ] Swift Language Version: Swift 5.9
- [ ] Frameworks linked: AVFoundation, Accelerate, SwiftUI, Combine

### 3. Info.plist / Capabilities
- [ ] Microphone Usage Description added
- [ ] Audio Capture Usage Description added
- [ ] iOS: Background Modes → Audio enabled (if needed)

### 4. Build Verification
- [ ] Project builds without errors (⌘B)
- [ ] No missing imports or unresolved identifiers
- [ ] All files compile successfully

### 5. Run Verification
- [ ] App launches successfully (⌘R)
- [ ] Tab bar appears with 5 tabs
- [ ] Record tab shows device picker
- [ ] Settings tab shows high-contrast toggle

## 🧪 Testing Checklist

### Basic Functionality
- [ ] Record tab: Device picker works
- [ ] Record tab: Record button responds
- [ ] Record tab: Meters display (when recording)
- [ ] Settings tab: High-contrast toggle works
- [ ] Calibrate tab: Loopback test button works
- [ ] Transcode tab: Drag & drop area appears
- [ ] Measure IR tab: Controls appear

### Advanced Features
- [ ] Load mic profile from Resources/Presets/AmbiAlice_v1.json
- [ ] Run loopback calibration
- [ ] Verify calibration profile is saved
- [ ] Test IR measurement (simulation)
- [ ] Test export functions

## 📝 Next Steps After Setup

1. **Connect Hardware**: Connect 4+ channel audio interface
2. **Run Calibration**: Perform loopback calibration
3. **Load Mic Profile**: Update AmbiAlice_v1.json with your measured matrix
4. **Test Recording**: Record a test session
5. **Test Export**: Export to different formats

## 🐛 Common Issues

### Build Errors
- **"Cannot find type"**: Check file is in target membership
- **"Missing framework"**: Verify frameworks are linked
- **"Use of unresolved identifier"**: Check imports

### Runtime Errors
- **"No input devices"**: Check microphone permissions
- **"Need ≥4 channels"**: Connect 4+ channel interface
- **"File not found"**: Check Resources are in bundle

### Test Errors
- **"Tests not found"**: Verify test files are in test target
- **"Cannot find module"**: Check test target links same frameworks

## 📚 Resources

- [Xcode Setup Guide](DOCS/XCODE_SETUP.md) - Detailed setup instructions
- [Architecture](DOCS/ARCHITECTURE.md) - Code structure overview
- [Usage Guide](README.md#usage-guide) - How to use each feature

## ✨ You're Ready!

Once all checkboxes are complete, you're ready to start using AmbiGlass!

