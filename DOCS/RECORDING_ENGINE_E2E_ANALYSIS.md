# Recording Engine End-to-End Analysis

## Overview
This document provides a comprehensive analysis of the `RecorderEngine` class, including all taps, endpoints, data flow, and state management.

## File Locations
- **Primary Implementation**: `ios/AmbiStudio/Audio/RecorderEngine.swift` (278 lines)
- **Legacy Implementation**: `Audio/RecorderEngine.swift` (97 lines) - appears to be older/simpler version
- **Dependencies**: 
  - `RecordingFolderManager.swift` - manages recording file locations
  - `AmbisonicsDSP.swift` - processes A-format to B-format conversion
  - `AudioDeviceManager.swift` - manages audio device enumeration

---

## Architecture

### Core Components
1. **AVAudioEngine** - Core audio processing engine
2. **AVAudioFile Writers** - Two file writers (A-format safety, B-format output)
3. **AmbisonicsDSP** - DSP processing for A-to-B format conversion
4. **Combine Publishers** - Meter data streaming via `meterPublisher`

---

## Endpoints (Public API)

### 1. `start(sampleRate:bufferFrames:) throws`
**Location**: Lines 154-225

**Purpose**: Starts recording session

**Flow**:
1. Stops monitoring if active (line 156)
2. Stops engine if already running (lines 159-162)
3. Resets file writers (lines 165-166)
4. Configures AVAudioSession (iOS only, lines 168-174)
5. Validates input device channels (lines 180-192)
6. Creates audio format for 4 channels (line 194)
7. Applies interface gains from calibration profile (lines 197-200)
8. Creates file writers in recording folder (lines 202-209)
9. **Installs tap on bus 0** (lines 213-222)
10. Starts engine (line 224)

**Parameters**:
- `sampleRate: Double = 48000`
- `bufferFrames: AVAudioFrameCount = 1024`

**Throws**: 
- Error code -1: Insufficient channels
- Error code -2: Selected channels out of range
- Error code -3: Not exactly 4 channels selected

**State Changes**:
- Sets `isRecordingActive = true` (line 212)
- Creates `aWriter` and `bWriter` file handles

---

### 2. `stop()`
**Location**: Lines 227-238

**Purpose**: Stops recording session

**Flow**:
1. Sets `isRecordingActive = false` (line 228)
2. Removes tap from bus 0 (line 229)
3. Stops engine (line 230)
4. Releases file writers (lines 231-232)
5. Restarts monitoring if 4 channels were selected (lines 234-237)

**State Changes**:
- Clears recording state
- Optionally restarts monitoring

---

### 3. `startMonitoring(sampleRate:bufferFrames:)`
**Location**: Lines 32-140

**Purpose**: Starts input level monitoring (meters only, no recording)

**Flow**:
1. Cancels existing monitoring task (line 34)
2. Stops if already monitoring (lines 37-39)
3. Validates device and channel selection (lines 42-50)
4. Prevents start if recording is active (lines 53-55)
5. Checks for redundant restarts (lines 58-60)
6. Creates background task (line 63)
7. Configures AVAudioSession (iOS only, lines 76-79)
8. Stops engine if running (lines 81-84)
9. Validates hardware format (lines 88-101)
10. **Installs tap on bus 0 with nil format** (line 104)
11. Starts engine (line 111)
12. Falls back to hardware format if start fails (lines 116-131)

**Parameters**:
- `sampleRate: Double = 48000`
- `bufferFrames: AVAudioFrameCount = 4096`

**State Changes**:
- Sets `isMonitoring = true` (lines 112, 126)
- Stores `lastMonitorSignature` (line 60)
- Creates `monitoringTask` (line 63)

**Threading**: Runs on `audioEngineQueue` (line 73) and background task (line 63)

---

### 4. `stopMonitoring()`
**Location**: Lines 142-152

**Purpose**: Stops input level monitoring

**Flow**:
1. Cancels monitoring task (lines 144-145)
2. Removes tap if engine running and not recording (lines 147-150)
3. Stops engine (line 149)
4. Sets `isMonitoring = false` (line 151)

**State Changes**:
- Clears monitoring state
- Does NOT affect recording state

---

### 5. `meterPublisher: AnyPublisher<[CGFloat], Never>`
**Location**: Lines 10-14

**Purpose**: Publishes meter levels for UI display

**Flow**:
- Wraps `meterSubject` with 100ms throttling
- Publishes array of 4 `CGFloat` values (one per channel)

**Subscribers**: `RecordView` (line 212)

---

## Published Properties

### `@Published var selectedDeviceID: String`
- **Default**: `"__no_devices__"` (line 17)
- **Purpose**: Tracks selected audio input device
- **Observers**: `RecordView` (lines 80-102)

### `@Published var selectedInputChannels: [Int]`
- **Default**: `[]` (line 18)
- **Purpose**: Tracks which input channels are selected (must be 4 for recording)
- **Observers**: `RecordView` (lines 149-169)

### `@Published var safetyRecord: Bool`
- **Default**: `true` (line 19)
- **Purpose**: Controls whether A-format safety recording is enabled
- **Observers**: `RecordView` (line 205)

---

## Taps (Audio Processing Points)

### Tap 1: Recording Tap
**Location**: Lines 213-222

**Installation**:
```swift
input.installTap(onBus: 0, bufferSize: bufferFrames, format: hw) { [weak self] buf, _ in
```

**Format**: Hardware format (`hw`) from input node

**Buffer Size**: `bufferFrames` (default 1024)

**Processing Pipeline**:
1. Extract first 4 channels via `extractFirstFourChannels()` (line 215)
2. Write A-format to file if `safetyRecord` enabled (line 216)
3. Process A-to-B format conversion via DSP (line 218)
4. Write B-format to file (line 219)
5. Push meter levels (line 221)

**Active When**: `isRecordingActive == true`

**Removed When**: `stop()` is called (line 229)

---

### Tap 2: Monitoring Tap
**Location**: Lines 104-108 (primary), 119-123 (fallback)

**Installation**:
```swift
input.installTap(onBus: 0, bufferSize: bufferFrames, format: nil) { [weak self] buf, _ in
```

**Format**: `nil` (uses hardware format), falls back to `hw` if start fails

**Buffer Size**: `bufferFrames` (default 4096)

**Processing Pipeline**:
1. Check recording is not active (line 105)
2. Extract first 4 channels via `extractFirstFourChannels()` (line 106)
3. Push meter levels only (line 107)

**Active When**: `isMonitoring == true` AND `isRecordingActive == false`

**Removed When**: `stopMonitoring()` is called (line 148)

---

## Data Flow

### Recording Flow
```
AVAudioEngine.inputNode
    ↓ (tap on bus 0, hardware format)
extractFirstFourChannels()
    ↓ (4-channel buffer)
    ├─→ aWriter.write() [if safetyRecord]
    ├─→ AmbisonicsDSP.processAtoB()
    │   ↓ (B-format buffer)
    │   └─→ bWriter.write()
    └─→ pushMeters()
        ↓ (meterSubject)
        └─→ meterPublisher (throttled 100ms)
            ↓
            RecordView (UI meters)
```

### Monitoring Flow
```
AVAudioEngine.inputNode
    ↓ (tap on bus 0, nil format)
extractFirstFourChannels()
    ↓ (4-channel buffer)
    └─→ pushMeters()
        ↓ (meterSubject)
        └─→ meterPublisher (throttled 100ms)
            ↓
            RecordView (UI meters)
```

---

## Channel Extraction

### `extractFirstFourChannels(buffer:) -> AVAudioPCMBuffer`
**Location**: Lines 240-259

**Purpose**: Maps selected input channels to output channels 0-3

**Algorithm**:
1. Creates 4-channel output buffer (lines 242-244)
2. Iterates through first 4 selected channels (line 247)
3. For each output channel:
   - Gets corresponding input channel from `selectedInputChannels` (line 250)
   - Clamps to available channel range (line 252)
   - Copies channel data (lines 253-255)

**Key Logic**:
- Uses `selectedInputChannels` array to map channels
- Clamps invalid channel indices to valid range
- Preserves frame count and sample rate

**Difference from Legacy**: Legacy version (Audio/RecorderEngine.swift) always uses channels 0-3 directly, ignoring selection.

---

## Meter Processing

### `pushMeters(from:)`
**Location**: Lines 261-276

**Purpose**: Computes peak levels and publishes to meters

**Algorithm**:
1. Decimates updates (every Nth call, line 264)
2. For each of 4 channels:
   - Gets float channel data pointer (line 269)
   - Computes peak magnitude using `vDSP_maxmgv` (line 272)
   - Clamps to 1.0 (line 273)
3. Sends array to `meterSubject` (line 275)

**Decimation**: `meterDecimateCounter % meterDecimateN` (line 264)
- Reduces update rate to avoid UI overload
- `meterDecimateN = 2` (line 27)

**Performance**: Uses Accelerate framework (`vDSP_maxmgv`) for efficient peak detection

---

## State Management

### State Variables
- `isMonitoring: Bool` - Monitoring active flag
- `isRecordingActive: Bool` - Recording active flag
- `monitoringTask: Task<Void, Never>?` - Background monitoring task
- `lastMonitorSignature: String?` - Prevents redundant monitoring starts

### State Transitions

**Idle → Monitoring**:
- Triggered by: `startMonitoring()` when 4 channels selected
- Conditions: Device selected, 4 channels selected, not recording

**Monitoring → Recording**:
- Triggered by: `start()` called
- Actions: Stops monitoring, starts recording

**Recording → Monitoring**:
- Triggered by: `stop()` called
- Actions: Stops recording, restarts monitoring if 4 channels still selected

**Any → Idle**:
- Triggered by: `stopMonitoring()` or device/channel changes

### Mutual Exclusivity
- `isRecordingActive` and `isMonitoring` are mutually exclusive
- Monitoring tap checks `!isRecordingActive` (line 105)
- Recording tap does not check monitoring state (assumes monitoring stopped first)

---

## File I/O

### A-Format Writer (`aWriter`)
- **Created**: Line 204 (if `safetyRecord == true`)
- **Format**: 4-channel Float32, non-interleaved
- **Location**: `RecordingFolderManager.shared.getFolder()`
- **Filename**: `Aformat_<timestamp>.wav`
- **Purpose**: Safety backup of raw A-format input

### B-Format Writer (`bWriter`)
- **Created**: Line 209 (always)
- **Format**: 4-channel Float32, non-interleaved
- **Location**: `RecordingFolderManager.shared.getFolder()`
- **Filename**: `BformatAmbiX_<timestamp>.wav`
- **Purpose**: Processed B-format output (AmbiX convention)

### File Management
- Files created in `RecordingFolderManager` managed folder
- Default fallback: `Documents/AmbiStudio Recordings`
- Files persist after recording stops (writers released but files remain)

---

## Threading Model

### Main Thread
- UI updates via `@Published` properties
- Meter publisher throttled and dispatched to main
- `RecordView` receives meter updates on main thread

### Background Threads
- `audioEngineQueue` (line 28): Serial queue for audio engine operations
- `monitoringTask`: Detached task for monitoring setup (line 63)
- Tap callbacks: Run on audio engine's internal thread (not main)

### Thread Safety
- `[weak self]` captures prevent retain cycles
- State checks in tap callbacks prevent race conditions
- `isRecordingActive` flag prevents concurrent tap processing

---

## Error Handling

### Validation Errors
1. **Insufficient channels**: Throws error code -1
2. **Channels out of range**: Throws error code -2
3. **Not 4 channels**: Throws error code -3

### Silent Failures
- File write errors: Swallowed with `try?` (lines 216, 219)
- Monitoring start failures: Logged but don't throw (lines 116-131)
- Invalid format: Returns early without error (lines 90-101)

### Recovery
- Monitoring retries with hardware format if nil format fails (lines 116-131)
- Engine restart on device change (lines 81-84)
- Automatic monitoring restart after recording stops (lines 234-237)

---

## Integration Points

### With AudioDeviceManager
- Reads `selectedDeviceID` to determine input device
- Device changes trigger monitoring restart (RecordView lines 80-102)

### With AmbisonicsDSP
- Applies interface gains from calibration profile (lines 197-200)
- Processes A-to-B format conversion (line 218)
- Uses `processAtoB(aBuffer:)` method

### With RecordingFolderManager
- Gets recording folder path (line 202)
- Creates files in managed folder

### With UI (RecordView)
- Publishes meter levels via `meterPublisher`
- Responds to `selectedDeviceID` and `selectedInputChannels` changes
- Receives recording start/stop commands

---

## Potential Issues & Recommendations

### 1. Tap Removal Race Condition
**Issue**: Tap removal in `stop()` (line 229) may occur while tap callback is executing
**Risk**: Low (AVFoundation handles this internally)
**Recommendation**: None needed

### 2. File Write Errors Swallowed
**Issue**: File write errors use `try?` and are silently ignored (lines 216, 219)
**Risk**: Medium (recordings may fail silently)
**Recommendation**: Add error logging or propagate errors

### 3. Monitoring Task Cancellation
**Issue**: `monitoringTask` cancellation doesn't wait for completion
**Risk**: Low (Task handles cancellation gracefully)
**Recommendation**: None needed

### 4. Channel Clamping Logic
**Issue**: `extractFirstFourChannels` clamps invalid channels (line 252) without warning
**Risk**: Medium (may record wrong channels silently)
**Recommendation**: Add validation warning or error

### 5. Format Mismatch Potential
**Issue**: Recording uses hardware format, but creates Float32 format buffers
**Risk**: Low (AVFoundation handles conversion)
**Recommendation**: None needed

### 6. Duplicate Tap Prevention
**Issue**: No explicit check for existing tap before installing
**Risk**: Low (code stops engine first, but could be more explicit)
**Recommendation**: Add explicit tap removal check

### 7. Meter Decimation Counter Overflow
**Issue**: `meterDecimateCounter` uses `&+=` which can overflow
**Risk**: Very Low (overflow is harmless in this context)
**Recommendation**: None needed

---

## Testing Recommendations

### Unit Tests Needed
1. Channel extraction with various `selectedInputChannels` arrays
2. Meter computation accuracy
3. State transition correctness
4. Error handling paths

### Integration Tests Needed
1. Full recording cycle (start → record → stop)
2. Monitoring → Recording → Monitoring transition
3. Device change during monitoring
4. File I/O verification
5. DSP processing verification

### Edge Cases to Test
1. Recording with invalid channel selection
2. Starting recording while monitoring active
3. Device disconnection during recording
4. Multiple rapid start/stop cycles
5. File system full condition

---

## DSP Integration Details

### AmbisonicsDSP.processAtoB()
**Location**: `DSP/AmbisonicsDSP.swift` lines 65-95

**Called From**: Recording tap (line 218)

**Processing Steps**:
1. Creates 4-channel output buffer (W, Y, Z, X - AmbiX SN3D convention)
2. Applies capsule trims (from mic profile) as linear gains
3. Applies interface gains (from calibration) as linear gains
4. Multiplies A-format channels by combined gains
5. Applies 4x4 transformation matrix (from mic profile)
6. Optionally applies orientation rotation (yaw/pitch/roll)

**Matrix Operation**:
```
[W]   [m0  m1  m2  m3 ]   [A0*g0]
[Y] = [m4  m5  m6  m7 ] × [A1*g1]
[Z]   [m8  m9  m10 m11]   [A2*g2]
[X]   [m12 m13 m14 m15]   [A3*g3]
```

Where `g0..g3` = `capsuleTrims[i] * interfaceGains[i]`

**Gain Application**:
- Capsule trims: Loaded from mic profile JSON (default: AmbiAlice_v1.json)
- Interface gains: Applied from `ProfileStore.shared.latestInterfaceProfile()` (line 198-199)
- Both converted from dB to linear: `powf(10.0, dB/20.0)`

**Output Format**: AmbiX SN3D convention (W, Y, Z, X order)

---

## Summary

The `RecorderEngine` is a well-structured audio recording system with:
- **2 taps**: Recording tap and monitoring tap (mutually exclusive)
- **5 public endpoints**: `start()`, `stop()`, `startMonitoring()`, `stopMonitoring()`, `meterPublisher`
- **Clear data flow**: Input → Channel extraction → DSP → File I/O → Meters
- **Robust state management**: Prevents conflicts between monitoring and recording
- **Thread-safe design**: Uses queues and weak references appropriately
- **DSP integration**: Real-time A-to-B format conversion with calibration support

The primary implementation in `ios/AmbiStudio/Audio/RecorderEngine.swift` is significantly more advanced than the legacy version in `Audio/RecorderEngine.swift`, with monitoring support, channel selection, and better error handling.

---

## Quick Reference: All Taps and Endpoints

### Taps (2 total)
1. **Recording Tap** (Bus 0, hardware format, 1024 frames)
   - Installed: `start()` line 213
   - Removed: `stop()` line 229
   - Processes: A-format → B-format → File I/O → Meters

2. **Monitoring Tap** (Bus 0, nil/hardware format, 4096 frames)
   - Installed: `startMonitoring()` lines 104, 119
   - Removed: `stopMonitoring()` line 148
   - Processes: A-format → Meters only

### Endpoints (5 total)
1. `start(sampleRate:bufferFrames:) throws` - Starts recording
2. `stop()` - Stops recording
3. `startMonitoring(sampleRate:bufferFrames:)` - Starts meter monitoring
4. `stopMonitoring()` - Stops meter monitoring
5. `meterPublisher: AnyPublisher<[CGFloat], Never>` - Meter level stream

### Internal Methods (3 total)
1. `extractFirstFourChannels(buffer:)` - Channel mapping
2. `pushMeters(from:)` - Peak detection and publishing
3. `linearGains(from:)` (DSP) - dB to linear conversion

