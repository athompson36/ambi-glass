# Recording Diagnostic Report
Generated: 2025-01-13

## Critical Issues Identified

### 1. **"Invalid frame dimension" Error**
**Location**: AVAudioPCMBuffer initialization
**Root Cause**: The error occurs when `AVAudioPCMBuffer(pcmFormat:frameCapacity:)` is called with parameters that result in invalid memory layout.

**Analysis**:
- Error message: "Invalid frame dimension (negative or non-finite)"
- This is an internal AVAudioPCMBuffer validation error
- Occurs even when parameters appear valid (sr=48000.0, ch=4)
- Likely caused by format mismatch or memory alignment issues

### 2. **Format Creation Failure**
**Location**: `AVAudioEngineRecorder.extractChannels()`
**Issue**: `AVAudioFormat(commonFormat:channels:interleaved:)` returns nil on macOS for 4-channel formats

**Why**:
- macOS AVAudioEngine has limitations with multi-channel formats
- Aggregate devices (28-channel) may not support direct 4-channel extraction
- System may reject non-standard channel configurations

### 3. **Zero Meters**
**Root Cause**: 
- Buffer extraction fails → returns original buffer
- Original buffer may have wrong channel count or format
- Meters process wrong channels or empty data

### 4. **Platform-Specific Issues**
- **macOS**: AVAudioEngine struggles with aggregate devices
- **Channel Selection**: Selecting channels [4,5,6,7] but device may only have 2 channels available to AVAudioEngine
- **Format Mismatch**: Hardware format vs requested format mismatch

## Diagnostic Findings

### Hardware Format Detection
```
🔍 AVAudioEngine: Hardware format - sampleRate: 48000.0, channels: 2, commonFormat: 1, isInterleaved: false
```

**Problem**: Device reports 2 channels, but we're trying to extract channels [4,5,6,7]

### Buffer Flow
1. AVAudioEngine provides 2-channel buffer
2. `extractChannels()` tries to create 4-channel format → **FAILS**
3. Returns original 2-channel buffer
4. Meters try to read channels 0-3 from 2-channel buffer → **ZEROS**

### Format Creation Chain
```
AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 4, interleaved: false)
  ↓ (returns nil on macOS for 4-channel)
Fallback: Returns original buffer (2 channels)
  ↓
Meters read channels [0,1,2,3] from 2-channel buffer
  ↓
Channels 2,3 don't exist → ZEROS
```

## Solutions Required

### Immediate Fixes

1. **Validate Available Channels Before Extraction**
   - Check `buffer.format.channelCount` before attempting extraction
   - Only extract channels that actually exist
   - Map selected channels to available channels

2. **Robust Format Creation**
   - Use `AVAudioFormat(standardFormatWithSampleRate:channels:)` as fallback
   - Derive format from input buffer if standard fails
   - Never return buffer with mismatched channel count

3. **Channel Mapping**
   - If device has 2 channels, map [4,5,6,7] → [0,1,0,1] (wrap around)
   - Or reject invalid channel selections with clear error

4. **Buffer Validation**
   - Validate `frameLength` is positive and finite
   - Validate `sampleRate` is positive and finite
   - Validate `channelCount` matches expectations

### Long-term Solutions

1. **Device Capability Detection**
   - Query actual available channels before allowing selection
   - Warn user if selected channels exceed available

2. **Format Compatibility Layer**
   - Create format converter utility
   - Handle all format mismatches gracefully

3. **Better Error Reporting**
   - Log actual format values when creation fails
   - Provide actionable error messages to user

## Code Locations to Fix

1. `AVAudioEngineRecorder.extractChannels()` - Lines 53-103
2. `AVAudioEngineRecorder.startMonitoring()` - Lines 131-208
3. `RecorderEngine.pushMeters()` - Lines 162-184
4. Channel selection validation in UI layer

## Recommended Fix Priority

1. **HIGH**: Fix channel mapping when selected channels exceed available
2. **HIGH**: Add format creation fallback chain
3. **MEDIUM**: Improve error messages and diagnostics
4. **LOW**: Add device capability detection UI

