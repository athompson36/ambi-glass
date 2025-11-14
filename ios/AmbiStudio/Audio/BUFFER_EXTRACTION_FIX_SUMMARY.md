# AVAudioEngine Buffer Extraction Fix Summary

## Problem Identified

**Error:** `Invalid frame dimension (negative or non-finite)`

**Location:** `AVAudioEngineRecorder.extractChannels()` method

**Root Causes:**
1. Buffer validation was insufficient - checking `frameLength > 0` doesn't guarantee valid buffer creation
2. Sample rate could be 0, negative, or non-finite (NaN, Infinity)
3. Channel count validation was missing
4. Error messages were generic and didn't help diagnose the actual issue
5. **Critical:** RecorderEngine was hardcoded to use `AVAudioEngineRecorder` on macOS instead of `CoreAudioRecorder`

## Debug Output Analysis

```
Invalid frame dimension (negative or non-finite).
⚠️ Failed to create extraction format (sr=48000.0, ch=4), returning original buffer
MeterPublisher output: ["0.000", "0.000", "0.000", "0.000"]
```

This indicates:
- AVAudioPCMBuffer creation was failing despite valid-looking parameters
- Meters were all zeros (no audio flowing)
- The extraction was falling back to original buffer (which might have wrong channel count)

## Solutions Implemented

### 1. Enhanced Buffer Validation in `extractChannels()`

**Before:**
```swift
guard let finalFmt = fmt,
      let out = AVAudioPCMBuffer(pcmFormat: finalFmt, frameCapacity: frameCount) else {
    print("⚠️ Failed to create extraction format...")
    return buffer
}
```

**After:**
```swift
// Validate ALL input parameters before attempting buffer creation
guard frameCount > 0 else {
    print("⚠️ AVAudioEngine: Invalid frameCount=\(frameCount)")
    return buffer
}

guard sampleRate > 0 && sampleRate.isFinite else {
    print("⚠️ AVAudioEngine: Invalid sampleRate=\(sampleRate)")
    return buffer
}

guard targetChannels > 0 && targetChannels <= 1024 else {
    print("⚠️ AVAudioEngine: Invalid targetChannels=\(targetChannels)")
    return buffer
}

// Now create buffer with validated parameters
guard let fmt = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: sampleRate,
    channels: AVAudioChannelCount(targetChannels),
    interleaved: false
) else {
    print("⚠️ AVAudioEngine: Failed to create Float32 format")
    return buffer
}
```

**Benefits:**
- Catches invalid parameters BEFORE attempting buffer creation
- Provides specific error messages for each failure case
- Validates sample rate is finite (not NaN or Infinity)
- Validates channel count is reasonable (1-1024)

### 2. Added Comprehensive Diagnostic Logging

**Monitoring Start:**
```swift
print("🔍 AVAudioEngine: Hardware format - sampleRate: \(hw.sampleRate), channels: \(hw.channelCount), commonFormat: \(hw.commonFormat.rawValue), isInterleaved: \(hw.isInterleaved)")
print("🔍 AVAudioEngine: Installing tap - bufferSize: \(bufferFrames), channelsToExtract: \(channelsToUse)")
```

**In Tap Callback:**
```swift
guard buf.frameLength > 0, buf.format.channelCount > 0 else {
    if self.meterDecimateCounter < 3 {
        print("⚠️ AVAudioEngine: Received invalid buffer - frameLength: \(buf.frameLength), channels: \(buf.format.channelCount)")
    }
    return
}
```

**Benefits:**
- Shows exactly what format the hardware provides
- Logs buffer parameters at tap installation
- Warns about invalid buffers received from AVAudioEngine
- Throttles repeated warnings to avoid log spam

### 3. Fixed Platform-Specific Recorder Selection

**Before (RecorderEngine.swift line 42):**
```swift
private let recorder: AudioRecorderProtocol = AVAudioEngineRecorder()
```

**After:**
```swift
#if os(macOS)
private let recorder: AudioRecorderProtocol = CoreAudioRecorder()
#else
private let recorder: AudioRecorderProtocol = AVAudioEngineRecorder()
#endif
```

**Why This Matters:**
- macOS should use CoreAudioRecorder for direct HAL access and better multi-channel support
- AVAudioEngine has limitations on macOS with certain audio interfaces
- This was likely causing the buffer extraction issues in the first place

## Changes Made

### AVAudioEngineRecorder.swift

1. **Line ~53-103:** Completely rewrote `extractChannels()` with robust validation
2. **Line ~160:** Added hardware format diagnostics at monitoring start
3. **Line ~165:** Added tap installation diagnostics
4. **Line ~172:** Added invalid buffer warnings in tap callback
5. **Line ~270:** Added hardware format diagnostics at recording start
6. **Line ~275:** Added tap installation diagnostics for recording
7. **Line ~280:** Added invalid buffer warnings in recording tap callback

### RecorderEngine.swift

1. **Line ~39-45:** Fixed platform-specific recorder initialization

## Expected Results

### Before Fix
```
❌ Invalid frame dimension (negative or non-finite).
⚠️ Failed to create extraction format (sr=48000.0, ch=4)
MeterPublisher output: ["0.000", "0.000", "0.000", "0.000"]
```

### After Fix (macOS)
```
✅ CoreAudio: Stream configuration - 2 streams: [14, 14]
✅ CoreAudio: Monitoring started - sampleRate: 48000.0Hz
MeterPublisher output: ["0.234", "0.189", "0.301", "0.256"]
```

### After Fix (iOS - if still using AVAudioEngine)
```
🔍 AVAudioEngine: Hardware format - sampleRate: 48000.0, channels: 2, commonFormat: 1, isInterleaved: false
🔍 AVAudioEngine: Installing tap - bufferSize: 16384, channelsToExtract: [0, 1, 0, 1]
✅ AVAudioEngine: Monitoring started - sampleRate: 48000.0Hz, channels: [0, 1, 0, 1]
MeterPublisher output: ["0.234", "0.189", "0.301", "0.256"]
```

## Root Cause Analysis

The issue was likely a **cascade of problems**:

1. **Wrong recorder on macOS** → AVAudioEngine struggled with multi-channel/aggregate devices
2. **Invalid buffers from AVAudioEngine** → frameLength or format was corrupt
3. **Insufficient validation** → Bad parameters passed to AVAudioPCMBuffer initializer
4. **Generic error messages** → Hard to diagnose what was actually failing

The fix addresses all layers:
- ✅ Use proper recorder for platform (CoreAudio on macOS)
- ✅ Validate ALL parameters before buffer creation
- ✅ Add diagnostics to see exactly what's happening
- ✅ Gracefully handle invalid buffers without crashing

## Testing Recommendations

1. **macOS Testing:**
   - Test with built-in audio input
   - Test with USB audio interfaces (2-channel, 4-channel)
   - Test with aggregate devices (multiple interfaces combined)
   - Verify CoreAudioRecorder is being used (check logs)

2. **iOS Testing (if applicable):**
   - Test with built-in microphone
   - Test with USB-C audio interfaces
   - Test with Bluetooth audio devices

3. **Verify Behavior:**
   - Meters should show non-zero values when audio is present
   - No "Invalid frame dimension" errors in console
   - Diagnostic logs should show proper format detection
   - Recording should capture audio correctly

4. **Edge Cases:**
   - Switching devices while monitoring
   - Switching sample rates
   - Changing channel selection

## Performance Notes

- Validation checks are minimal overhead (few CPU cycles)
- Diagnostic logging only happens at setup time (not in hot path)
- Buffer callback warnings are throttled with `meterDecimateCounter`
- No impact on real-time audio performance

---

**Status:** ✅ Ready for testing
**Date:** November 13, 2025
**Related Fix:** COREAUDIO_FIX_SUMMARY.md (CoreAudio -50 error fix)
