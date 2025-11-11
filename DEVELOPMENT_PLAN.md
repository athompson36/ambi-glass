# AmbiStudio Development Plan

**Date:** November 7, 2025  
**Status:** Ready for Continued Development  
**Project:** AmbiStudio (formerly AmbiGlass)

---

## Current Status Summary

### ✅ Completed
- **Xcode Project**: Fixed and building successfully
- **Source Files**: All integrated into Xcode project
- **Build Errors**: All resolved (Accelerate framework, Combine imports, string interpolation)
- **Basic Tests**: 4/4 tests passing (template tests)
- **Project Structure**: Clean and organized

### ⚠️ In Progress
- **Test Integration**: Existing tests from `Tests/` directory need to be integrated into Xcode test target
- **Test Conversion**: Tests need to be converted from function-based to Swift Testing framework

### 📋 Pending
- **Documentation Updates**: Some outdated references in ARCHITECTURE.md
- **Integration Tests**: Full recording pipeline tests
- **Hardware Testing**: Real audio interface validation

---

## Development Priorities

### Priority 1: Test Integration & Conversion (IMMEDIATE)

**Goal**: Integrate existing comprehensive tests into Xcode and convert to Swift Testing framework

**Tasks**:
1. ✅ **Add test files to Xcode test target**
   - Add `Tests/AmbisonicsDSPTests.swift` to `AmbiStudioTests` target
   - Add `Tests/IRDeconvolutionTests.swift` to `AmbiStudioTests` target
   - Add `Tests/CalibrationTests.swift` to `AmbiStudioTests` target
   - Add `Tests/CalibrationCurveTest.swift` to `AmbiStudioTests` target

2. ⏳ **Convert tests to Swift Testing framework**
   - Convert `testAtoBMapping()` → `@Test func testAtoBMapping()`
   - Convert `testOrientationTransform()` → `@Test func testOrientationTransform()`
   - Convert `testIRDeconvolution()` → `@Test func testIRDeconvolution()`
   - Convert `testCalibrationLatency()` → `@Test func testCalibrationLatency()`
   - Convert `testCalibrationGains()` → `@Test func testCalibrationGains()`
   - Convert `testCalibrationCurvePreview()` → `@Test func testCalibrationCurvePreview()`

3. ⏳ **Replace assert() with #expect()**
   - Update all assertions to use Swift Testing's `#expect()` macro
   - Add proper error messages

4. ⏳ **Run full test suite**
   - Verify all tests pass
   - Check test coverage

**Expected Outcome**: 
- All existing tests integrated and passing
- Tests use modern Swift Testing framework
- Full test coverage for DSP, IR, and Calibration modules

---

### Priority 2: Documentation Updates (SHORT-TERM)

**Goal**: Update documentation to reflect actual implementation status

**Tasks**:
1. ⏳ **Update ARCHITECTURE.md**
   - Remove "to be implemented" references for completed features
   - Update IRKit description: "FFT-based deconvolution with windowing" ✅
   - Update Transcoder description: "multi-format export (AmbiX, FuMa, Stereo, 5.1, 7.1, Binaural)" ✅
   - Update IR measurement flow description

2. ⏳ **Update DEVELOPMENT_STATUS.md**
   - Mark Xcode integration as complete
   - Update test status
   - Remove outdated issues

3. ⏳ **Update README.md**
   - Ensure all feature descriptions are accurate
   - Update project name references (AmbiGlass → AmbiStudio)
   - Verify all links work

**Expected Outcome**:
- All documentation accurately reflects current implementation
- No outdated "to be implemented" references
- Consistent project naming

---

### Priority 3: Integration Tests (MEDIUM-TERM)

**Goal**: Add integration tests for full recording pipeline

**Tasks**:
1. ⏳ **Audio I/O Integration Tests**
   - Test device enumeration
   - Test recording start/stop
   - Test file creation
   - Test peak meters

2. ⏳ **Recording Pipeline Tests**
   - Test A-format recording
   - Test A→B conversion during recording
   - Test B-format file output
   - Test safety A-format toggle

3. ⏳ **Calibration Integration Tests**
   - Test loopback test execution
   - Test profile persistence
   - Test auto-apply to recordings

4. ⏳ **IR Measurement Integration Tests**
   - Test sweep generation
   - Test measurement workflow
   - Test IR export

**Expected Outcome**:
- Full integration test coverage
- End-to-end workflow validation
- Confidence in full system functionality

---

### Priority 4: Hardware Testing Preparation (MEDIUM-TERM)

**Goal**: Prepare for real hardware testing

**Tasks**:
1. ⏳ **Test Plan Documentation**
   - Document hardware requirements
   - Create test procedures
   - Define acceptance criteria

2. ⏳ **Mic Profile Calibration**
   - Measure actual Ambi-Alice microphone matrix
   - Update `Resources/Presets/AmbiAlice_v1.json` with real data
   - Verify A→B conversion accuracy

3. ⏳ **Hardware Test Checklist**
   - 4-channel interface detection
   - Recording pipeline validation
   - Calibration system validation
   - IR measurement validation
   - Export format verification

**Expected Outcome**:
- Ready for hardware testing
- Clear test procedures
- Validated mic profiles

---

## Test Coverage Analysis

### Current Test Coverage

**Unit Tests Available** (in `Tests/` directory):
- ✅ A→B mapping with synthetic impulses
- ✅ Orientation transforms
- ✅ IR deconvolution with known IRs
- ✅ Calibration latency estimation
- ✅ Calibration gain estimation
- ✅ Calibration curve preview

**Integration Tests Needed**:
- ⏳ Audio I/O (device enumeration, recording)
- ⏳ Recording pipeline (A→B conversion, file output)
- ⏳ Calibration workflow (loopback test, profile persistence)
- ⏳ IR measurement workflow (sweep generation, measurement, export)

**UI Tests Needed**:
- ⏳ Record view interactions
- ⏳ Settings view interactions
- ⏳ Calibration view interactions
- ⏳ IR measurement view interactions
- ⏳ Transcode view interactions

---

## Implementation Plan

### Phase 1: Test Integration (Week 1)
1. Add test files to Xcode test target
2. Convert tests to Swift Testing framework
3. Run and verify all tests pass
4. Document test results

### Phase 2: Documentation Updates (Week 1-2)
1. Update ARCHITECTURE.md
2. Update DEVELOPMENT_STATUS.md
3. Update README.md
4. Review all documentation for accuracy

### Phase 3: Integration Tests (Week 2-3)
1. Create integration test structure
2. Implement audio I/O tests
3. Implement recording pipeline tests
4. Implement calibration integration tests
5. Implement IR measurement integration tests

### Phase 4: Hardware Testing Prep (Week 3-4)
1. Document hardware test procedures
2. Prepare mic profile calibration
3. Create hardware test checklist
4. Schedule hardware testing session

---

## Next Immediate Steps

1. **Start with Test Integration** (Highest Priority)
   - Add test files to Xcode project
   - Convert first test file to Swift Testing framework
   - Verify it works
   - Continue with remaining tests

2. **Run Full Test Suite**
   - Execute all unit tests
   - Verify all pass
   - Document results

3. **Update Documentation**
   - Fix outdated references
   - Ensure accuracy
   - Update project status

---

## Success Criteria

### Test Integration Complete When:
- ✅ All test files added to Xcode test target
- ✅ All tests converted to Swift Testing framework
- ✅ All tests passing (100% pass rate)
- ✅ Test coverage documented

### Documentation Complete When:
- ✅ No outdated "to be implemented" references
- ✅ All feature descriptions accurate
- ✅ Project naming consistent
- ✅ All links working

### Integration Tests Complete When:
- ✅ Audio I/O tests passing
- ✅ Recording pipeline tests passing
- ✅ Calibration integration tests passing
- ✅ IR measurement integration tests passing

### Hardware Testing Ready When:
- ✅ Test procedures documented
- ✅ Mic profiles calibrated
- ✅ Test checklist created
- ✅ Hardware available for testing

---

## Risk Assessment

### Low Risk
- Test integration (straightforward conversion)
- Documentation updates (text changes only)

### Medium Risk
- Integration tests (may require mock objects)
- Hardware testing (requires physical equipment)

### Mitigation
- Start with low-risk tasks
- Test incrementally
- Document as we go
- Prepare hardware test environment early

---

## Resources Needed

### Development
- ✅ Xcode project (ready)
- ✅ Source code (ready)
- ✅ Test files (ready)
- ⏳ Test framework knowledge (Swift Testing)

### Testing
- ⏳ 4-channel audio interface
- ⏳ Ambi-Alice microphone
- ⏳ Test audio files
- ⏳ Test environment setup

---

**Status**: ✅ **Ready to begin test integration**

**Next Action**: Integrate existing tests into Xcode test target and convert to Swift Testing framework

