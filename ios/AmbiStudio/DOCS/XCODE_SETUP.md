# Xcode Project Setup Guide

This guide walks you through creating a new Xcode project and integrating all AmbiGlass source files.

## Step 1: Create New Xcode Project

1. **Open Xcode** → File → New → Project
2. **Select Template**: 
   - Choose "App" under iOS/macOS
   - Select "Multiplatform" tab
   - Choose "App" template
3. **Configure Project**:
   - **Product Name**: `AmbiGlass`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: None (or your preference)
   - **Include Tests**: ✅ Yes
4. **Save Location**: Choose your desired location
5. **Click "Create"**

## Step 2: Remove Default Files

Delete the auto-generated files:
- `ContentView.swift` (we have our own)
- `AmbiGlassApp.swift` (we have our own)
- Any default assets

## Step 3: Add Source Files

### 3.1 Create Folder Structure

In Xcode, right-click the project → New Group, create these groups:

```
AmbiGlass
├── App
├── Audio
├── DSP
├── Transcode
├── UI
├── Theme
├── Resources
│   └── Presets
└── Tests
```

### 3.2 Add Files to Groups

**App Group:**
- `App/AmbiGlassApp.swift`
- `App/ContentView.swift`

**Audio Group:**
- `Audio/AudioDeviceManager.swift`
- `Audio/RecorderEngine.swift`

**DSP Group:**
- `DSP/AmbisonicsDSP.swift`
- `DSP/IRKit.swift`
- `DSP/CalibrationKit.swift`
- `DSP/MicCalLoader.swift`
- `DSP/Profiles.swift`

**Transcode Group:**
- `Transcode/Transcoder.swift`

**UI Group:**
- `UI/RecordView.swift`
- `UI/MeasureIRView.swift`
- `UI/BatchTranscodeView.swift`
- `UI/CalibrationView.swift`
- `UI/SettingsView.swift`
- `UI/CalibrationCurveView.swift`

**Theme Group:**
- `Theme/LiquidGlassTheme.swift`
- `Theme/ThemeManager.swift`

**Resources → Presets:**
- `Resources/Presets/AmbiAlice_v1.json`

**Tests Group:**
- `Tests/AmbisonicsDSPTests.swift`
- `Tests/IRDeconvolutionTests.swift`
- `Tests/CalibrationTests.swift`
- `Tests/CalibrationCurveTest.swift`
- `Tests/TestRunner.swift`

### 3.3 Add Files to Project

1. **Drag & Drop Method**:
   - Open Finder, navigate to the AmbiGlass_starter folder
   - Select all files from each group
   - Drag into corresponding Xcode group
   - **Important**: Check "Copy items if needed" ✅
   - **Important**: Select "Create groups" (not folder references)
   - **Target Membership**: Check "AmbiGlass" for all source files

2. **Or Add Files Manually**:
   - Right-click each group → "Add Files to AmbiGlass..."
   - Navigate to the file
   - Check "Copy items if needed" ✅
   - Select "Create groups"
   - Check target membership

## Step 4: Configure Build Settings

### 4.1 General Settings

1. **Select Project** in Navigator
2. **Select Target** "AmbiGlass"
3. **General Tab**:
   - **Deployment Info**:
     - macOS: 14.0+
     - iOS: 17.0+
   - **Supported Platforms**: macOS, iOS

### 4.2 Build Settings

1. **Swift Language Version**: Swift 5.9
2. **Swift Compiler - Code Generation**:
   - **Optimization Level**: Debug: None, Release: Optimize for Speed
3. **Linking**:
   - **Other Linker Flags**: Add `-framework Accelerate` (if not auto-linked)

### 4.3 Capabilities

**macOS Target:**
- **App Sandbox**: Enable if needed
- **Audio Input**: ✅ Required
- **Audio Output**: ✅ Required (for IR measurement)

**iOS Target:**
- **Audio Background Modes**: ✅ Required
- **Microphone Usage**: Add to Info.plist:
  ```xml
  <key>NSMicrophoneUsageDescription</key>
  <string>AmbiGlass needs microphone access to record ambisonic audio</string>
  ```

## Step 5: Add Frameworks

1. **Select Target** → **General** → **Frameworks, Libraries, and Embedded Content**
2. **Click "+"** and add:
   - `AVFoundation.framework` (should be auto-linked)
   - `Accelerate.framework` (should be auto-linked)
   - `SwiftUI.framework` (should be auto-linked)
   - `Combine.framework` (should be auto-linked)

## Step 6: Configure Info.plist

### macOS Info.plist

Add to `Info.plist` or `Info` tab in target settings:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>AmbiGlass needs microphone access to record ambisonic audio</string>
<key>NSAudioCaptureUsageDescription</key>
<string>AmbiGlass needs audio capture access for ambisonic recording</string>
```

### iOS Info.plist

Same as above, plus:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

## Step 7: Set Up Test Target

1. **Select Test Target** "AmbiGlassTests"
2. **General Tab**:
   - **Host Application**: AmbiGlass
3. **Build Phases**:
   - **Compile Sources**: Add all test files
   - **Link Binary With Libraries**: Add same frameworks as main target

## Step 8: Build and Run

1. **Select Scheme**: AmbiGlass → macOS (or iOS)
2. **Select Device**: 
   - macOS: "My Mac"
   - iOS: Simulator or connected device
3. **Build**: ⌘B (or Product → Build)
4. **Run**: ⌘R (or Product → Run)

## Step 9: Verify Build

### Check for Errors

1. **Build Log**: Check for any compilation errors
2. **Common Issues**:
   - Missing imports: Add `import AVFoundation`, `import Accelerate`, etc.
   - Missing files: Verify all files are added to target
   - Framework linking: Check frameworks are linked

### Test Basic Functionality

1. **Launch App**: Should show tab bar with 5 tabs
2. **Record Tab**: Should show device picker and record button
3. **Settings Tab**: Should show high-contrast toggle
4. **Calibrate Tab**: Should show loopback test button

## Step 10: Run Tests

1. **Select Test Target**: AmbiGlassTests
2. **Run Tests**: ⌘U (or Product → Test)
3. **View Results**: Test Navigator (⌘6)

## Troubleshooting

### Build Errors

**"Cannot find type 'AmbisonicsDSP'"**
- Check file is added to target membership
- Clean build folder: ⌘⇧K
- Rebuild: ⌘B

**"Missing required module 'AVFoundation'"**
- Verify framework is linked in target settings
- Check deployment target matches framework version

**"Use of unresolved identifier"**
- Check imports at top of file
- Verify all dependencies are linked

### Runtime Errors

**"No input devices found"**
- macOS: Check System Preferences → Security & Privacy → Microphone
- iOS: Check Info.plist has microphone usage description

**"Need ≥4 input channels"**
- Connect a 4+ channel audio interface
- Check device is selected in Record tab

### Test Errors

**"Tests not found"**
- Verify test files are in test target
- Check test methods start with `test`
- Ensure test target is configured correctly

## Project Structure Checklist

After setup, your project should look like:

```
AmbiGlass.xcodeproj
├── App/
│   ├── AmbiGlassApp.swift ✅
│   └── ContentView.swift ✅
├── Audio/
│   ├── AudioDeviceManager.swift ✅
│   └── RecorderEngine.swift ✅
├── DSP/
│   ├── AmbisonicsDSP.swift ✅
│   ├── IRKit.swift ✅
│   ├── CalibrationKit.swift ✅
│   ├── MicCalLoader.swift ✅
│   └── Profiles.swift ✅
├── Transcode/
│   └── Transcoder.swift ✅
├── UI/
│   ├── RecordView.swift ✅
│   ├── MeasureIRView.swift ✅
│   ├── BatchTranscodeView.swift ✅
│   ├── CalibrationView.swift ✅
│   ├── SettingsView.swift ✅
│   └── CalibrationCurveView.swift ✅
├── Theme/
│   ├── LiquidGlassTheme.swift ✅
│   └── ThemeManager.swift ✅
├── Resources/
│   └── Presets/
│       └── AmbiAlice_v1.json ✅
└── Tests/
    ├── AmbisonicsDSPTests.swift ✅
    ├── IRDeconvolutionTests.swift ✅
    ├── CalibrationTests.swift ✅
    ├── CalibrationCurveTest.swift ✅
    └── TestRunner.swift ✅
```

## Next Steps

1. **Test on Device**: Connect 4+ channel interface and test recording
2. **Load Mic Profile**: Update `AmbiAlice_v1.json` with your measured matrix
3. **Run Calibration**: Perform loopback calibration
4. **Test IR Measurement**: Generate test IRs
5. **Verify Exports**: Test all export formats

## Additional Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [AVFoundation Guide](https://developer.apple.com/documentation/avfoundation)

