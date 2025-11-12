# AmbiGlass Production Roadmap

**Last Updated:** December 2024  
**Project Status:** 95% Complete - Production Ready (Pending Hardware Testing)  
**Version:** v0.4+ (Pre-Release)

---

## Executive Summary

AmbiGlass is a professional ambisonic capture and processing application for macOS/iPadOS, designed for 4-channel Ambi-Alice microphones. The project has reached **95% completion** with all core features implemented and recently enhanced with new capabilities including recording folder management, physical channel selection, and IR reverb audition.

### Current State
- ✅ **Core Application**: 95% complete - All features implemented, ready for hardware testing
- ⚠️ **IR Measurement**: 90% complete - Algorithms ready, live capture integration pending
- ⚠️ **AmbiIRverb Plugin**: 25% complete - Infrastructure ready, DSP algorithms need implementation
- ✅ **Documentation**: 95% complete - Comprehensive docs with minor updates needed

### Release Readiness
- **Main App**: Ready for beta testing after hardware validation
- **Plugin**: 3-4 months from v1.0 release (DSP implementation required)

---

## Phase 1: Pre-Release (Current Phase)

**Timeline:** 2-4 weeks  
**Status:** In Progress  
**Goal:** Complete hardware testing and fix critical issues

### 1.1 Hardware Testing & Validation (CRITICAL)

**Priority:** 🔴 **BLOCKER**

#### Tasks
- [ ] **4-Channel Interface Testing**
  - Test with real Ambi-Alice microphone setup
  - Validate 4-channel simultaneous capture
  - Verify real-time A→B conversion accuracy
  - Test peak metering accuracy
  - Validate safety A-format recording

- [ ] **Calibration System Validation**
  - Test loopback calibration with real hardware
  - Verify latency measurement accuracy
  - Validate per-channel gain offset calculation
  - Test auto-apply to recordings
  - Verify profile persistence

- [ ] **IR Measurement Testing**
  - Test ESS sweep generation and playback
  - Validate live capture integration (if implemented)
  - Verify deconvolution accuracy with real IRs
  - Test IR export formats (mono, stereo, true-stereo, FOA)
  - Validate windowing and normalization

- [ ] **Export Format Validation**
  - Test AmbiX export (W,Y,Z,X ordering, ACN/SN3D normalization)
  - Test FuMa export (W,X,Y,Z ordering, FuMa scaling)
  - Validate stereo, 5.1, 7.1 surround decodes
  - Verify file format compatibility with DAWs
  - Test batch transcoding workflow

- [ ] **Mic Profile Calibration**
  - Measure actual Ambi-Alice microphone matrix
  - Update `Resources/Presets/AmbiAlice_v1.json` with real data
  - Verify A→B conversion accuracy with measured profile
  - Test frequency response calibration curves

#### Acceptance Criteria
- ✅ All recording features work with real hardware
- ✅ Calibration system produces accurate results
- ✅ IR measurement produces valid impulse responses
- ✅ All export formats are DAW-compatible
- ✅ Mic profiles are accurate and validated

### 1.2 IR Measurement Live Capture Implementation (HIGH PRIORITY)

**Priority:** 🟡 **HIGH**

#### Current Status
- ✅ ESS generation algorithm complete
- ✅ Deconvolution algorithm complete
- ✅ UI complete with device/channel selection
- ⚠️ `IRKit.runSweep()` uses mock data (not live capture)

#### Tasks
- [ ] **Implement Live Audio Playback**
  - Integrate AVAudioEngine for ESS sweep playback
  - Route to selected output device/channels
  - Implement real-time playback with progress tracking
  - Handle playback errors gracefully

- [ ] **Implement Live Audio Capture**
  - Integrate AVAudioEngine for simultaneous capture
  - Capture from selected input device/channels
  - Synchronize capture with playback timing
  - Handle capture errors gracefully

- [ ] **Update IRKit Integration**
  - Replace mock data in `runSweep()` with live capture
  - Implement proper timing synchronization
  - Add progress callbacks for UI feedback
  - Handle edge cases (dropouts, buffer underruns)

#### Acceptance Criteria
- ✅ ESS sweep plays through selected outputs
- ✅ Input capture synchronized with playback
- ✅ Deconvolution produces valid IRs from live capture
- ✅ Error handling for audio I/O issues
- ✅ Progress feedback during measurement

### 1.3 Test Suite Integration & Fixes (MEDIUM PRIORITY)

**Priority:** 🟡 **MEDIUM**

#### Tasks
- [ ] **Integrate Existing Tests into Xcode**
  - Add all test files to Xcode test target
  - Convert tests to Swift Testing framework
  - Replace `assert()` with `#expect()`
  - Fix test execution issues

- [ ] **Fix Test Crashes**
  - Investigate and fix unit test crashes
  - Verify all DSP tests pass
  - Validate calibration tests
  - Ensure IR deconvolution tests work

- [ ] **Add Integration Tests**
  - Audio I/O integration tests
  - Recording pipeline end-to-end tests
  - Calibration workflow tests
  - IR measurement workflow tests

#### Acceptance Criteria
- ✅ All unit tests pass (100% pass rate)
- ✅ Integration tests cover main workflows
- ✅ Tests use modern Swift Testing framework
- ✅ Test coverage documented

### 1.4 Documentation Updates (LOW PRIORITY)

**Priority:** 🟢 **LOW**

#### Tasks
- [ ] **Update Architecture Documentation**
  - Remove "to be implemented" references
  - Update IRKit description (fully implemented)
  - Update Transcoder description (fully implemented)
  - Document recent enhancements

- [ ] **Update Status Documents**
  - Update DEVELOPMENT_STATUS.md with current state
  - Update PROJECT_STATUS.md with recent features
  - Document hardware testing procedures
  - Add hardware testing guide

- [ ] **User Documentation**
  - Update README with latest features
  - Document recording folder management
  - Document physical channel selection
  - Document IR reverb audition feature

#### Acceptance Criteria
- ✅ All documentation accurate and up-to-date
- ✅ No outdated "to be implemented" references
- ✅ Hardware testing guide available
- ✅ User guide reflects all features

---

## Phase 2: Beta Release (Post-Hardware Testing)

**Timeline:** 4-6 weeks after Phase 1  
**Status:** Planned  
**Goal:** Public beta release with core features validated

### 2.1 Beta Testing Program

#### Tasks
- [ ] **Beta Tester Recruitment**
  - Recruit 10-20 beta testers with Ambi-Alice setups
  - Provide beta testing guide
  - Set up feedback collection system
  - Create beta testing checklist

- [ ] **Beta Release Preparation**
  - Package app for distribution (macOS App Store or direct)
  - Create beta release notes
  - Set up crash reporting (if applicable)
  - Prepare feedback collection tools

- [ ] **Beta Testing Period**
  - Monitor feedback and bug reports
  - Prioritize critical issues
  - Collect feature requests
  - Document common issues

#### Acceptance Criteria
- ✅ Beta testers actively using the app
- ✅ Feedback collection system working
- ✅ Critical bugs identified and prioritized
- ✅ Beta testing period completed (2-4 weeks)

### 2.2 Bug Fixes & Polish

#### Tasks
- [ ] **Critical Bug Fixes**
  - Fix all blocker bugs from beta testing
  - Address crash reports
  - Fix audio I/O issues
  - Resolve calibration problems

- [ ] **UI/UX Improvements**
  - Address usability feedback
  - Improve error messages
  - Enhance visual feedback
  - Optimize workflow efficiency

- [ ] **Performance Optimization**
  - Profile long recordings
  - Optimize memory usage
  - Tune buffer sizes for different sample rates
  - Optimize DSP processing

#### Acceptance Criteria
- ✅ All critical bugs fixed
- ✅ UI/UX improvements implemented
- ✅ Performance meets targets
- ✅ App stable for production use

### 2.3 Release Preparation

#### Tasks
- [ ] **Final Testing**
  - Complete regression testing
  - Test on multiple macOS/iPadOS versions
  - Test with various audio interfaces
  - Validate all export formats

- [ ] **Documentation Finalization**
  - Complete user manual
  - Create video tutorials (optional)
  - Update all documentation
  - Prepare release notes

- [ ] **Distribution Setup**
  - Set up App Store listing (if applicable)
  - Prepare direct distribution (if applicable)
  - Create installer/package
  - Set up update mechanism

#### Acceptance Criteria
- ✅ All tests passing
- ✅ Documentation complete
- ✅ Distribution ready
- ✅ Release notes prepared

---

## Phase 3: Production Release (v1.0)

**Timeline:** 2-4 weeks after Phase 2  
**Status:** Planned  
**Goal:** Public release of v1.0

### 3.1 Production Release

#### Tasks
- [ ] **Final Release Checklist**
  - Verify all features working
  - Complete final testing
  - Prepare release build
  - Create release announcement

- [ ] **Launch Activities**
  - Release to App Store / direct distribution
  - Announce release on website/social media
  - Provide support channels
  - Monitor initial user feedback

#### Acceptance Criteria
- ✅ v1.0 released publicly
- ✅ All core features functional
- ✅ Documentation available
- ✅ Support channels active

### 3.2 Post-Release Support

#### Tasks
- [ ] **Monitor & Support**
  - Monitor crash reports
  - Respond to user feedback
  - Address critical issues quickly
  - Plan hotfix releases if needed

- [ ] **Gather Feedback**
  - Collect feature requests
  - Identify common issues
  - Plan future enhancements
  - Document lessons learned

#### Acceptance Criteria
- ✅ Support system active
- ✅ Critical issues addressed promptly
- ✅ User feedback collected
- ✅ Future roadmap updated

---

## Phase 4: Future Enhancements (Post-v1.0)

**Timeline:** Ongoing  
**Status:** Planned  
**Goal:** Continuous improvement and feature expansion

### 4.1 High-Priority Enhancements

#### Binaural HRTF Implementation
- [ ] **SOFA File Support**
  - Implement SOFA file loader
  - Parse HRTF data
  - Support multiple HRTF sets

- [ ] **HRTF-Based Binaural Rendering**
  - Implement binaural rendering algorithm
  - Real-time binaural preview during recording
  - Binaural export with HRTF

- [ ] **Binaural Preview**
  - Real-time binaural monitoring
  - Headphone-optimized output
  - Latency optimization

**Estimated Timeline:** 6-8 weeks

#### Advanced IR Features
- [ ] **Advanced IR Windowing**
  - Multiple window types
  - Custom window shapes
  - Time-domain editing

- [ ] **Frequency Response Analysis**
  - Real-time frequency analysis
  - IR frequency response visualization
  - Frequency-dependent processing

**Estimated Timeline:** 4-6 weeks

### 4.2 Medium-Priority Enhancements

#### Batch Processing Improvements
- [ ] **Multi-File Batch Processing**
  - Process multiple recordings
  - Batch format conversion
  - Progress tracking for batches

- [ ] **Preset Management UI**
  - Preset browser
  - Preset organization
  - Preset sharing

- [ ] **Export History & Favorites**
  - Track export history
  - Favorite export settings
  - Quick re-export

**Estimated Timeline:** 4-6 weeks

#### Workflow Enhancements
- [ ] **Project Management**
  - Project folders
  - Session management
  - Metadata tagging

- [ ] **Advanced Calibration**
  - Multi-point calibration
  - Frequency-dependent calibration
  - Calibration profiles library

**Estimated Timeline:** 6-8 weeks

### 4.3 Low-Priority Enhancements

#### Additional Features
- [ ] **Real-Time Monitoring Enhancements**
  - Spectrum analyzer
  - Phase correlation meter
  - Ambisonic visualization

- [ ] **Integration Features**
  - DAW integration (if applicable)
  - Cloud sync (optional)
  - Export presets for common DAWs

**Estimated Timeline:** 8-12 weeks

---

## Phase 5: AmbiIRverb Plugin Development

**Timeline:** 3-4 months from current state  
**Status:** Active Development (25% complete)  
**Goal:** v1.0 plugin release

### 5.1 Core DSP Implementation (CRITICAL)

**Priority:** 🔴 **HIGH**  
**Timeline:** 4-6 weeks

#### Tasks
- [ ] **Spring Engine Implementation**
  - Dispersive allpass ladder (4-6 stages)
  - Small delay tanks (2-4 parallel)
  - Optional "drip" effect (nonlinearity)
  - Time scaling via delay length modulation

- [ ] **Plate Engine Implementation**
  - 8-line FDN (Feedback Delay Network)
  - Householder mixing matrix
  - Frequency-dependent damping
  - Time scaling via delay lengths

- [ ] **Room Engine Implementation**
  - Early reflections generator (tap delay network)
  - 4-8 line Schroeder/FDN tail
  - Room size parameter (delay scaling)
  - Depth parameter (early/late balance)

- [ ] **Hall Engine Implementation**
  - 16-line FDN for long tails
  - LF-weighted decay
  - Soft HF damping
  - Large space simulation

- [ ] **Convolution Engine Enhancements**
  - True-stereo IR support (4-channel: LL, LR, RL, RR)
  - IR format auto-detection (mono/stereo/4ch)
  - Time scaling (via resampling or convolution length)
  - Latency reporting to host

#### Acceptance Criteria
- ✅ All engines produce quality reverb
- ✅ Engines meet CPU usage targets (< 5% per engine)
- ✅ True-stereo IR support working
- ✅ All parameters functional

### 5.2 Preset System (HIGH PRIORITY)

**Priority:** 🟡 **HIGH**  
**Timeline:** 1-2 weeks

#### Tasks
- [ ] **Preset Serialization**
  - JSON format (`.ambipreset`)
  - Save: APVTS state + IR path + metadata
  - Load: Restore all parameters + load IR
  - Error handling for missing IRs

- [ ] **Preset Browser UI**
  - File browser component
  - Preset list with preview
  - Load/Save/Delete actions
  - Preset naming and metadata

- [ ] **IR Management**
  - IR file browser
  - IR path persistence in presets
  - IR validation and error messages
  - Support for common formats (WAV, AIFF)

#### Acceptance Criteria
- ✅ Presets save/load correctly
- ✅ IR paths persist in presets
- ✅ Preset browser functional
- ✅ Error handling robust

### 5.3 UI Enhancements (MEDIUM PRIORITY)

**Priority:** 🟡 **MEDIUM**  
**Timeline:** 2-3 weeks

#### Tasks
- [ ] **Advanced Parameter Drawers**
  - Per-engine advanced controls
  - Collapsible sections
  - Engine-specific parameters

- [ ] **IR Loading UI**
  - File chooser button
  - IR info display (channels, length, sample rate)
  - IR preview (waveform visualization)
  - Drag-and-drop support

- [ ] **A/B Comparison**
  - A/B state storage
  - Toggle button
  - Visual indicator

- [ ] **Liquid Glass UI Polish**
  - Enhanced styling
  - Animations
  - Visual feedback
  - Tooltips

#### Acceptance Criteria
- ✅ UI complete and polished
- ✅ All features accessible
- ✅ Visual design consistent
- ✅ User experience smooth

### 5.4 Testing & Optimization (HIGH PRIORITY)

**Priority:** 🟡 **HIGH**  
**Timeline:** 2-3 weeks

#### Tasks
- [ ] **Unit Tests**
  - Engine algorithm tests
  - Parameter range validation
  - Edge case handling

- [ ] **Integration Tests**
  - Full signal path tests
  - Preset save/load tests
  - IR loading tests

- [ ] **Performance Optimization**
  - CPU usage profiling
  - Memory usage optimization
  - Real-time safety verification

- [ ] **Host Compatibility**
  - Test in major DAWs (Logic, Pro Tools, Reaper, etc.)
  - Automation testing
  - Preset compatibility

#### Acceptance Criteria
- ✅ All tests passing
- ✅ Performance meets targets
- ✅ Compatible with major DAWs
- ✅ Real-time safe

### 5.5 Plugin v1.0 Release

**Timeline:** 3-4 months from current state

#### Tasks
- [ ] **Release Preparation**
  - Final testing
  - Documentation completion
  - Distribution setup
  - Release announcement

#### Acceptance Criteria
- ✅ Plugin v1.0 released
- ✅ All features functional
- ✅ Documentation complete
- ✅ Distribution ready

---

## Phase 6: Long-Term Vision (v2.0+)

**Timeline:** 6-12 months  
**Status:** Future Planning  
**Goal:** Advanced features and ecosystem expansion

### 6.1 Dolby Atmos Support (v2.0)

#### Tasks
- [ ] **Multibus Architecture**
  - 7.1.4 channel support
  - VST3/AU multibus configuration
  - Per-channel processing

- [ ] **Multichannel Convolution**
  - HOA (Higher Order Ambisonics) IR support
  - HOA→bed decoding
  - True-stereo per ear pair

- [ ] **Binaural Preview**
  - Headphone binaural rendering
  - HRTF integration
  - Preview mode toggle

**Estimated Timeline:** 8-12 weeks

### 6.2 Ecosystem Integration

#### Tasks
- [ ] **Cloud Integration** (Optional)
  - Cloud preset sync
  - IR library sharing
  - Project backup

- [ ] **DAW Integration** (If Applicable)
  - ARA support
  - Plugin format enhancements
  - Workflow integration

- [ ] **Mobile App** (Future Consideration)
  - iOS/iPadOS companion app
  - Remote control
  - Mobile recording

**Estimated Timeline:** TBD

---

## Risk Assessment & Mitigation

### High-Risk Items

1. **Hardware Testing Delays**
   - **Risk:** Limited access to Ambi-Alice hardware
   - **Mitigation:** Partner with hardware manufacturer, use simulation where possible

2. **IR Live Capture Complexity**
   - **Risk:** Audio I/O synchronization challenges
   - **Mitigation:** Use proven AVAudioEngine patterns, extensive testing

3. **Plugin DSP Implementation**
   - **Risk:** Complex algorithms, time-consuming
   - **Mitigation:** Phased approach, reference implementations, expert consultation

### Medium-Risk Items

1. **Beta Testing Feedback Volume**
   - **Risk:** Overwhelming feedback, conflicting priorities
   - **Mitigation:** Structured feedback collection, clear prioritization

2. **Performance Optimization**
   - **Risk:** CPU/memory constraints on older devices
   - **Mitigation:** Profiling, optimization passes, device testing

### Low-Risk Items

1. **Documentation Updates**
   - **Risk:** Minor, manageable
   - **Mitigation:** Continuous updates, review process

---

## Success Metrics

### Phase 1 (Pre-Release)
- ✅ All hardware tests passing
- ✅ IR live capture functional
- ✅ All unit tests passing
- ✅ Documentation updated

### Phase 2 (Beta Release)
- ✅ 10+ active beta testers
- ✅ < 5 critical bugs
- ✅ Positive user feedback (> 80% satisfaction)
- ✅ Performance targets met

### Phase 3 (Production Release)
- ✅ v1.0 released publicly
- ✅ < 1% crash rate
- ✅ Positive reviews (> 4.0/5.0)
- ✅ Active user base

### Phase 5 (Plugin Release)
- ✅ Plugin v1.0 released
- ✅ All engines functional
- ✅ DAW compatibility verified
- ✅ Performance targets met

---

## Timeline Summary

| Phase | Duration | Start | End | Status |
|-------|----------|-------|-----|--------|
| **Phase 1: Pre-Release** | 2-4 weeks | Current | TBD | 🔄 In Progress |
| **Phase 2: Beta Release** | 4-6 weeks | After Phase 1 | TBD | 📋 Planned |
| **Phase 3: Production Release** | 2-4 weeks | After Phase 2 | TBD | 📋 Planned |
| **Phase 4: Future Enhancements** | Ongoing | After v1.0 | Ongoing | 📋 Planned |
| **Phase 5: Plugin Development** | 3-4 months | Current | TBD | 🔄 Active |
| **Phase 6: Long-Term Vision** | 6-12 months | Future | TBD | 📋 Future |

---

## Dependencies

### External Dependencies
- **Ambi-Alice Hardware**: Required for hardware testing
- **4+ Channel Audio Interface**: Required for testing
- **JUCE Framework**: Required for plugin development
- **macOS/iPadOS SDK**: Required for app development

### Internal Dependencies
- **Hardware Testing** → Blocks Beta Release
- **IR Live Capture** → Blocks Production Release (if critical)
- **Plugin DSP Implementation** → Blocks Plugin v1.0
- **Beta Testing** → Blocks Production Release

---

## Resources

### Documentation
- [Architecture](DOCS/ARCHITECTURE.md)
- [Development Status](DEVELOPMENT_STATUS.md)
- [Feature Status](FEATURE_STATUS_REPORT.md)
- [Plugin Integration](DOCS/PLUGIN_INTEGRATION.md)
- [Plugin Roadmap](Plugins/AmbiIRverb/docs/DEVELOPMENT_ROADMAP.md)

### Key Files
- `README.md` - Project overview
- `CHANGELOG.md` - Version history
- `PROJECT_STATUS.md` - Current status
- `DEVELOPMENT_PLAN.md` - Development plan

---

**Document Maintained By:** Development Team  
**Review Cycle:** Monthly or as needed  
**Last Updated:** December 2024  
**Next Review:** January 2025

