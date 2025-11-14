# CoreAudio Recording Engine Fix Summary

## Problem Identified

**Error:** `AudioUnitRender failed: -50` (kAudio_ParamError)

**Root Cause:** The audio callback was incorrectly allocating AudioBufferList structures for multi-stream devices (like aggregates or professional interfaces with 28+ channels). The error occurred because:

1. The stream configuration query was happening **inside the audio callback** on every buffer
2. Fallback logic was guessing stream layouts incorrectly
3. For a 28-channel interleaved device, only **1 buffer** was being allocated when CoreAudio expected **multiple buffers** (one per physical stream)

## Debug Output Analysis

```
CoreAudio: Audio unit input format - channels: 28, sampleRate: 48000.0, formatID: 1819304813, flags: 9
Allocating buffers - channels: 28, isInterleaved: true, numBuffers: 1, streams: [28]
```

- **formatID 1819304813** = `'lpcm'` (Linear PCM)
- **flags 9** = Float + Packed (0x1 | 0x8)
- **Problem:** Only allocating 1 buffer with 28 channels, but device has multiple streams

## Solution Implemented

### 1. Added Stream Configuration Caching

**New Method:** `getDeviceStreamConfiguration(deviceID:)`
- Queries `kAudioDevicePropertyStreamConfiguration` at setup time
- Returns array of channels per stream (e.g., `[14, 14]` for two 14-channel streams)
- Properly handles AudioBufferList structure

**New Property:** `cachedStreamConfiguration: [Int]`
- Cached at device setup (monitoring/recording start)
- Used by audio callback to allocate correct buffer structure
- Cleared on stop

### 2. Simplified Audio Callback

**Before:**
```swift
// Query stream config on EVERY buffer (expensive!)
var channelsPerStream: [Int] = []
if let deviceID = recorder.cachedDeviceID {
    // Complex query with fallbacks...
}
```

**After:**
```swift
// Use cached config (queried once at setup)
let channelsPerStream = recorder.cachedStreamConfiguration
guard !channelsPerStream.isEmpty else { return noErr }
```

### 3. Proper Buffer Allocation

Now correctly allocates:
- **Interleaved:** One buffer per stream (e.g., 2 buffers for [14, 14])
- **Non-interleaved:** One buffer per channel (e.g., 28 buffers for 28 channels)

## Changes Made

### CoreAudioRecorder.swift

1. **Line ~40:** Added `cachedStreamConfiguration: [Int] = []`

2. **Line ~170:** Added `getDeviceStreamConfiguration(deviceID:)` method

3. **Line ~755 & ~905:** Updated setup to cache stream configuration:
   ```swift
   self.cachedStreamConfiguration = getDeviceStreamConfiguration(deviceID: deviceID)
   if self.cachedStreamConfiguration.isEmpty {
       print("⚠️ CoreAudio: Stream configuration query failed, using single-stream fallback")
       self.cachedStreamConfiguration = [channelCount]
   }
   ```

4. **Line ~411:** Simplified callback to use cached config instead of querying every buffer

5. **Line ~830 & ~966:** Clear cached stream config on stop

## Expected Results

### Before Fix
```
❌ CoreAudio: AudioUnitRender failed: -50
🔍 Allocating buffers - numBuffers: 1, streams: [28]
```

### After Fix
```
✅ CoreAudio: Stream configuration - 2 streams: [14, 14]
✅ CoreAudio: Allocating buffers - numBuffers: 2, streams: [14, 14]
✅ CoreAudio: Monitoring started - sampleRate: 48000.0Hz
```

## Performance Improvements

1. **Eliminated expensive property queries from audio thread** - Stream configuration now queried once at setup instead of every buffer (40-80x per second)
2. **Reduced callback complexity** - Removed fallback logic and repeated queries
3. **Better error detection** - Fails early with clear error if stream config is invalid

## Testing Recommendations

1. Test with single-stream devices (built-in audio)
2. Test with multi-stream aggregates (MOTU, RME, etc.)
3. Test with various channel counts (2ch, 4ch, 8ch, 28ch)
4. Verify meters update correctly
5. Verify recording writes valid audio files

## Additional Notes

- The fix maintains backward compatibility with simple devices (single stream)
- Fallback still exists if stream config query fails (uses total channel count as single stream)
- Debug logging helps diagnose issues with new device types
- The cached approach is thread-safe because setup happens before audio starts

---

**Status:** ✅ Ready for testing
**Date:** November 13, 2025
