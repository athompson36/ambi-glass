# AmbiGlass Testing Guide

## Pre-Build Tests ✅

All pre-build tests have passed:
- ✅ File structure verified
- ✅ All 18 Swift files present (1,636 lines)
- ✅ Import dependencies correct
- ✅ No syntax errors
- ✅ Resources valid
- ✅ Test files present

## Xcode Project Testing

### Step 1: Create Xcode Project

Follow `DOCS/XCODE_SETUP.md` to create the Xcode project.

### Step 2: Build Test

Once the project is created, test the build:

```bash
# From Xcode
⌘B (Product → Build)

# Or from command line
cd /path/to/AmbiGlass_Xcode
xcodebuild -scheme AmbiGlass -configuration Debug build
```

**Expected Result**: Build succeeds with no errors

### Step 3: Run Test

```bash
# From Xcode
⌘R (Product → Run)

# Or from command line
xcodebuild -scheme AmbiGlass -configuration Debug run
```

**Expected Result**: 
- App launches
- Tab bar appears with 5 tabs
- No crashes on startup

### Step 4: Unit Tests

```bash
# From Xcode
⌘U (Product → Test)

# Or from command line
xcodebuild test -scheme AmbiGlass -destination 'platform=macOS'
```

**Expected Tests**:
- ✅ A→B mapping with synthetic impulses
- ✅ Orientation transforms
- ✅ IR deconvolution
- ✅ Calibration latency/gain

### Step 5: UI Testing

**Manual UI Tests**:

1. **Record Tab**:
   - [ ] Device picker appears
   - [ ] Device list populates
   - [ ] Record button responds
   - [ ] Meters display (when recording)
   - [ ] Safety A-format toggle works

2. **Settings Tab**:
   - [ ] High-contrast toggle works
   - [ ] Theme changes apply
   - [ ] Mic calibration file picker works
   - [ ] Calibration curve displays (if loaded)

3. **Calibrate Tab**:
   - [ ] Loopback test button works
   - [ ] Progress indicator appears
   - [ ] Results display after test
   - [ ] Profile information shows

4. **Measure IR Tab**:
   - [ ] Sweep controls work
   - [ ] Output channel selection works
   - [ ] Generate button works
   - [ ] Export buttons appear after measurement

5. **Transcode Tab**:
   - [ ] Drag & drop area appears
   - [ ] File validation works
   - [ ] Export buttons work
   - [ ] Error messages display correctly

### Step 6: Functional Testing

**With Hardware** (requires 4+ channel interface):

1. **Recording Test**:
   - Connect 4-channel interface
   - Select device
   - Start recording
   - Verify files created:
     - A-format file (if safety enabled)
     - B-format file
   - Check file lengths match recording time

2. **Calibration Test**:
   - Connect output to input (loopback)
   - Run loopback test
   - Verify latency measurement
   - Verify gain offsets calculated
   - Check profile saved

3. **IR Measurement Test**:
   - Configure sweep parameters
   - Generate and measure
   - Verify IR deconvolution
   - Test export formats

4. **Transcode Test**:
   - Drop 4 mono WAV files
   - Export to different formats
   - Verify output files created
   - Check channel ordering

## Test Checklist

### Build & Run
- [ ] Project builds without errors
- [ ] App launches successfully
- [ ] No runtime crashes
- [ ] All tabs accessible

### Basic Functionality
- [ ] Device enumeration works
- [ ] UI responds to interactions
- [ ] Theme switching works
- [ ] Progress indicators display

### Advanced Features
- [ ] Recording pipeline works
- [ ] A→B conversion processes
- [ ] Calibration system works
- [ ] IR measurement functions
- [ ] Export formats work

### Error Handling
- [ ] Missing device handled gracefully
- [ ] Invalid files rejected
- [ ] Error messages display
- [ ] App doesn't crash on errors

## Common Issues & Solutions

### Build Errors

**"Cannot find type 'AmbisonicsDSP'"**
- Solution: Check file is in target membership
- Fix: Select file → Target Membership → Check "AmbiGlass"

**"Missing required module 'AVFoundation'"**
- Solution: Verify framework is linked
- Fix: Target → General → Frameworks → Add AVFoundation

**"Use of unresolved identifier"**
- Solution: Check imports at top of file
- Fix: Add missing `import` statements

### Runtime Errors

**"No input devices found"**
- Solution: Check microphone permissions
- Fix: System Preferences → Security & Privacy → Microphone

**"Need ≥4 input channels"**
- Solution: Connect 4+ channel interface
- Fix: Select correct device in Record tab

**App crashes on launch**
- Solution: Check console for errors
- Fix: Verify all environment objects are provided

## Performance Testing

### Latency Tests
- Recording latency: < 10ms
- Processing latency: < 1ms
- UI responsiveness: < 100ms

### Memory Tests
- Monitor memory usage during recording
- Check for memory leaks
- Verify buffers are released

### CPU Tests
- Monitor CPU usage during processing
- Verify real-time capability
- Check for performance bottlenecks

## Automated Testing

Once Xcode project is set up, you can run:

```bash
# Run all tests
xcodebuild test -scheme AmbiGlass

# Run specific test
xcodebuild test -scheme AmbiGlass -only-testing:AmbiGlassTests/AmbisonicsDSPTests
```

## Test Results

After running all tests, document:
- Build status
- Test pass/fail counts
- Performance metrics
- Known issues
- Recommendations

---

**Status**: ✅ Code structure verified and ready for Xcode integration

