# Memory Configuration Guide

## Current Situation

Your app is running on **macOS with App Sandbox enabled** (`ENABLE_APP_SANDBOX = YES`). This can impose memory restrictions, especially for large file processing.

## Memory Restrictions

### 1. App Sandbox Limits
- **Sandboxed macOS apps** have memory limits, but they're typically quite high (several GB)
- The limit is usually **not the issue** for 32GB RAM systems
- However, **memory pressure** from the system can still kill processes

### 2. Debug vs Release Mode
- **Debug builds** may have stricter memory limits and slower performance
- **Release builds** are optimized and have fewer restrictions

### 3. System Memory Pressure
- macOS may kill processes when system memory is under pressure
- Even with 32GB RAM, if other apps are using memory, the system may kill your process

## Solutions

### Option 1: Run in Release Mode (Recommended)

**In Xcode:**
1. Product → Scheme → Edit Scheme
2. Select "Run" → Info tab
3. Build Configuration: Change from "Debug" to "Release"
4. Click "Close"
5. Run the app (⌘R)

**Or via command line:**
```bash
xcodebuild -project ios/AmbiStudio/AmbiStudio.xcodeproj \
    -scheme AmbiStudio \
    -configuration Release \
    -sdk macosx \
    build
```

### Option 2: Temporarily Disable App Sandbox (Testing Only)

**⚠️ WARNING: Only for testing. Re-enable before production!**

1. Open `ios/AmbiStudio/AmbiStudio.xcodeproj` in Xcode
2. Select the project in Navigator
3. Select the "AmbiStudio" target
4. Go to "Signing & Capabilities" tab
5. Click the "−" button next to "App Sandbox" to remove it
6. Build and run

**To re-enable:**
- Click the "+ Capability" button
- Add "App Sandbox" back
- Re-enable the required entitlements (Audio Input, USB, etc.)

### Option 3: Increase System Memory Limits

**Check current limits:**
```bash
ulimit -a
```

**Increase memory limit (for current session):**
```bash
ulimit -v unlimited  # Virtual memory
ulimit -m unlimited  # Physical memory
```

**Note:** These limits apply to the shell session. To make permanent, add to `~/.zshrc`:
```bash
ulimit -v unlimited
ulimit -m unlimited
```

### Option 4: Add Memory Monitoring

The code already includes memory logging. Check the logs to see actual memory usage:
- Look for "Pre-finalize: physicalMemory=..." in console
- Monitor Activity Monitor while transcoding

### Option 5: Optimize File I/O

The code already uses:
- Chunked processing (16k frames per chunk)
- Autoreleasepool for immediate memory release
- Periodic flushing to reduce buffering

## Recommended Approach

1. **First, try Release mode** - This often solves memory issues
2. **Monitor memory usage** - Use Activity Monitor to see actual usage
3. **Close other apps** - Free up system memory before transcoding
4. **If still failing**, temporarily disable App Sandbox for testing

## Checking What's Killing the Process

**Check system logs:**
```bash
log show --predicate 'process == "AmbiStudio"' --last 1h | grep -i "killed\|memory\|pressure"
```

**Check memory pressure:**
```bash
memory_pressure
```

## Expected Memory Usage

For a 711M frame file (≈11GB at 48kHz):
- **Per chunk**: ~256KB (4 channels × 16k frames × 4 bytes)
- **Total processing memory**: Should stay under 1GB
- **File handle buffering**: Can be several GB (this is the likely issue)

The issue is likely **file handle buffering** during `fileHandle.close()`, not actual memory limits.

## Next Steps

1. Run in **Release mode** first
2. If still failing, check the new logging to see exactly where it's killed
3. Consider writing to a temporary location first, then moving the file
4. Or use direct file I/O instead of FileHandle for very large files

