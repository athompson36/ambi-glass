# CoreAudio Stream Configuration Detection - Enhanced Fix

## Problem Analysis

The error message is explicit:
```
ioData.mNumberBuffers=1, ASBD::NumberChannelStreams(output.GetStreamFormat())=2
kAudio_ParamError from AU: auou/ahal/appl, render err: -50
```

**Translation:**
- We're passing **1 buffer** to `AudioUnitRender`
- The AudioUnit expects **2 buffers** (2 streams)
- Your 28-channel device has **2 physical streams** of 14 channels each

**Root Cause:**
The `kAudioDevicePropertyStreamConfiguration` query is **failing or returning incorrect data** for your audio interface, causing the fallback to a single 28-channel stream `[28]` instead of two 14-channel streams `[14, 14]`.

## Why Device Query Fails

This can happen with:
1. **Aggregate devices** - macOS virtual combination of multiple interfaces
2. **Complex USB interfaces** - Multi-client audio devices
3. **Virtual audio routing** - BlackHole, Loopback, etc.
4. **Driver quirks** - Some manufacturers don't properly expose stream configuration

## Solution: Two-Level Fallback Strategy

### Level 1: Query Device (Preferred)
```swift
func getDeviceStreamConfiguration(deviceID: AudioDeviceID) -> [Int]
```
- Tries `kAudioObjectPropertyElementMain` first
- Falls back to `kAudioObjectPropertyElementWildcard`
- Returns stream layout like `[14, 14]` for two 14-channel streams

### Level 2: Query AudioUnit (Fallback)
```swift
func getAudioUnitStreamConfiguration(audioUnit: AudioUnit) -> [Int]
```
- **NEW**: Queries the initialized AudioUnit's expected stream configuration
- Uses `kAudioOutputUnitProperty_StreamConfiguration`
- Called **after** AudioUnit is created if device query failed
- More reliable for complex/aggregate devices

### Level 3: Single-Stream Assumption (Last Resort)
```swift
self.cachedStreamConfiguration = [channelCount]
```
- Assumes all channels in one stream
- Will fail for multi-stream devices (your case)

## Changes Made

### CoreAudioRecorder.swift

1. **Line ~168-232:** Enhanced `getDeviceStreamConfiguration()` with dual-element fallback
2. **Line ~234-286:** Added NEW `getAudioUnitStreamConfiguration()` method
3. **Line ~867-877:** Query AudioUnit streams if device query returned fallback
4. **Line ~1005-1015:** Same for recording start
5. **Line ~445-454:** Enhanced callback logging to show exactly what's happening

## Expected Diagnostic Output

### Successful Device Query
```
🔍 CoreAudio: Querying stream configuration for device 123...
🔍 CoreAudio: Stream config property size: 24 bytes
🔍 CoreAudio: AudioBufferList has 2 buffers
🔍 CoreAudio: Stream 0: 14 channels
🔍 CoreAudio: Stream 1: 14 channels
✅ CoreAudio: Stream configuration - 2 streams: [14, 14]
✅ CoreAudio: Cached stream configuration: [14, 14]
```

### Device Query Fails → AudioUnit Fallback Works
```
🔍 CoreAudio: Querying stream configuration for device 123...
❌ CoreAudio: Failed to get stream configuration size - status: -50, dataSize: 0
⚠️ CoreAudio: Stream configuration query failed, using single-stream fallback with 28 channels
🔍 CoreAudio: Attempting to query AudioUnit for stream configuration...
🔍 CoreAudio: AudioUnit stream 0: 14 channels
🔍 CoreAudio: AudioUnit stream 1: 14 channels
✅ CoreAudio: AudioUnit reports 2 streams: [14, 14]
✅ CoreAudio: Using AudioUnit stream configuration: [14, 14]
```

### Both Fail → Error in Callback
```
❌ CoreAudio: Failed to get stream configuration size - status: -50
⚠️ CoreAudio: Stream configuration query failed, using single-stream fallback
⚠️ CoreAudio: AudioUnit stream configuration not available
🔍 CoreAudio: Using cached streams: [28], sum: 28, audioUnit reports: 28
❌ CoreAudio: Stream config mismatch - cached sum: 28, audioUnit reports: 28
   This means the device stream configuration query failed at setup.
```

## Testing This Fix

1. **Build and run** - Check console for diagnostic output
2. **Look for** - "Using AudioUnit stream configuration: [14, 14]"
3. **Verify** - "Allocating buffers - numBuffers: 2, streams: [14, 14]"
4. **Confirm** - No more `-50` errors from AudioUnitRender

## If This Still Doesn't Work

If both queries fail, the issue might be with how the AudioUnit is configured. Potential next steps:

### Option A: Force Stream Layout Based on Common Patterns
```swift
// Common patterns for 28-channel devices:
if channelCount == 28 {
    // Most 28-ch interfaces are 2x14
    cachedStreamConfiguration = [14, 14]
} else if channelCount == 32 {
    // 2x16 or 4x8
    cachedStreamConfiguration = [16, 16]
}
```

### Option B: Set AudioUnit Stream Configuration Explicitly
```swift
// Configure the AudioUnit's expected stream layout
var streamConfig = AudioBufferList(...)
AudioUnitSetProperty(
    unit,
    kAudioOutputUnitProperty_StreamConfiguration,
    kAudioUnitScope_Input,
    1,
    &streamConfig,
    size
)
```

### Option C: Use Non-Interleaved Mode
Force the AudioUnit to deliver non-interleaved audio (one buffer per channel) by setting the stream format appropriately. This avoids the stream layout problem entirely.

## What We Learned

The Apple AudioUnit documentation is sparse on stream configuration, but the key insight is:

> **Interleaved multi-stream devices require one `AudioBuffer` per physical stream, not per channel.**

Your 28-channel interface has 2 physical streams (likely left bank 1-14, right bank 15-28). The HAL AudioUnit needs to know this layout to allocate buffers correctly.

The error message `ASBD::NumberChannelStreams(output.GetStreamFormat())=2` confirms the AudioUnit **knows** it needs 2 streams, but we were only giving it 1 buffer.

---

**Status:** ✅ Enhanced query with AudioUnit fallback
**Next:** Test and observe diagnostic output
**If fails:** Consider Option A (pattern matching) or Option C (non-interleaved)
