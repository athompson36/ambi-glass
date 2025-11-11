# AmbiGlass ConvoVerb - Development Roadmap

**Version:** 1.0.0 (Scaffold)  
**Last Updated:** 2025-01-27  
**Status:** Active Development

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Assessment](#current-state-assessment)
3. [Architecture Overview](#architecture-overview)
4. [Development Phases](#development-phases)
5. [Feature Specifications](#feature-specifications)
6. [Technical Debt & Issues](#technical-debt--issues)
7. [Testing Strategy](#testing-strategy)
8. [Performance Targets](#performance-targets)
9. [Timeline Estimates](#timeline-estimates)

---

## Executive Summary

AmbiGlass ConvoVerb is a hybrid reverb plugin combining convolution (IR) and algorithmic reverb engines (Spring, Plate, Room, Hall). The project is currently in **scaffold stage** with core infrastructure in place but most DSP algorithms and UI features incomplete.

### Project Status: **~25% Complete**

**Completed:**
- ✅ Project structure and build system (CMake + JUCE 8)
- ✅ Parameter system (APVTS with all controls)
- ✅ Basic UI layout and LookAndFeel
- ✅ Audio processing pipeline structure
- ✅ Engine routing system (HybridVerb)
- ✅ Basic DSP modules (Diffuser, ModTail, MsWidth, OutputEQ)

**In Progress / Incomplete:**
- ⚠️ All algorithmic engines are stubs (Spring, Plate, Room, Hall)
- ⚠️ Convolution engine lacks true-stereo support
- ⚠️ Preset save/load not implemented
- ⚠️ IR loading UI missing
- ⚠️ Advanced engine parameters not implemented
- ⚠️ Predelay not implemented
- ⚠️ Early/late split not implemented

---

## Current State Assessment

### Code Quality Analysis

#### ✅ Strengths
1. **Clean Architecture**: Well-separated concerns with engine interface pattern
2. **Modern C++**: Uses C++20, JUCE 8, proper RAII
3. **Thread Safety**: APVTS provides thread-safe parameter access
4. **Real-time Safe**: No allocations in processBlock (except stubs)
5. **Build System**: Robust CMake setup with JUCE FetchContent fallback

#### ⚠️ Critical Issues

1. **Algorithmic Engines (CRITICAL)**
   - All four engines (Spring, Plate, Room, Hall) use identical placeholder code
   - Same AP diffuser implementation copied to all
   - Engine parameters (`params`) are ignored (`juce::ignoreUnused(params)`)
   - No actual reverb algorithms implemented

2. **Convolution Engine**
   - Basic structure exists but lacks:
     - True-stereo (4-channel) IR support
     - IR time scaling
     - Latency reporting
     - IR format detection (mono/stereo/4ch)

3. **Preset System**
   - FileIO only provides folder path
   - No JSON serialization/deserialization
   - No preset browser UI
   - No IR path persistence

4. **UI Features**
   - Basic controls present but:
     - No preset management (load/save/browse)
     - No IR file browser
     - No advanced parameter drawers
     - No A/B comparison
     - No copy/paste

5. **DSP Pipeline**
   - Predelay missing (mentioned in architecture but not implemented)
   - Depth parameter not properly utilized
   - Early/late split not implemented

### File-by-File Status

| File | Status | Notes |
|------|--------|-------|
| `PluginProcessor.cpp` | ✅ Complete | Main audio processing pipeline |
| `PluginEditor.cpp` | ⚠️ Basic | UI layout done, features missing |
| `Parameters.cpp` | ✅ Complete | All parameters defined |
| `HybridVerb.cpp` | ✅ Complete | Engine routing works |
| `ConvoEngine.cpp` | ⚠️ Partial | Needs true-stereo, time scaling |
| `SpringEngine.cpp` | ❌ Stub | Placeholder code only |
| `PlateEngine.cpp` | ❌ Stub | Placeholder code only |
| `RoomEngine.cpp` | ❌ Stub | Placeholder code only |
| `HallEngine.cpp` | ❌ Stub | Placeholder code only |
| `Diffuser.cpp` | ✅ Complete | Basic diffusion working |
| `ModTail.cpp` | ✅ Complete | Modulation working |
| `MsWidth.cpp` | ✅ Complete | M/S width working |
| `OutputEQ.cpp` | ✅ Complete | 3-band EQ working |
| `FileIO.cpp` | ❌ Minimal | Only folder path |
| `LookAndFeel.cpp` | ⚠️ Basic | Needs more styling |

---

## Architecture Overview

### Audio Signal Flow

```
Input (Stereo)
  ↓
Pre-Filters (HP/LP) ──┐
  ↓                    │
Input Diffusion ──────┤
  ↓                    │
Predelay (TODO) ──────┤
  ↓                    │
Engine Selection ──────┤
  ├─ IR Convolution    │
  ├─ Spring Engine     │
  ├─ Plate Engine      │
  ├─ Room Engine       │
  └─ Hall Engine       │
  ↓                    │
Late Modulation ──────┤
  ↓                    │
Output EQ ────────────┤
  ↓                    │
M/S Width ────────────┤
  ↓                    │
Dry/Wet Mix ──────────┘
  ↓
Output (Stereo)
```

### Component Hierarchy

```
AmbiGlassConvoVerbAudioProcessor
├── Parameters (APVTS)
├── HybridVerb
│   ├── IRConvolutionEngine
│   ├── SpringEngine
│   ├── PlateEngine
│   ├── RoomEngine
│   └── HallEngine
├── Diffuser (pre-processing)
├── ModTail (post-processing)
├── OutputEQ
├── MsWidth
└── LiquidGlassLookAndFeel

AmbiGlassConvoVerbAudioProcessorEditor
├── Mode Selector (ComboBox)
├── Main Controls (Sliders)
├── Filter Controls
├── EQ Controls
└── (TODO: Preset Browser, IR Loader, Advanced Drawers)
```

---

## Development Phases

### Phase 1: Core DSP Implementation (Priority: CRITICAL)
**Goal:** Make all reverb engines functional  
**Estimated Time:** 4-6 weeks

#### 1.1 Spring Engine
- **Status:** ❌ Stub
- **Requirements:**
  - Dispersive allpass ladder (4-6 stages)
  - Small delay tanks (2-4 parallel)
  - Optional "drip" effect (nonlinearity)
  - Time scaling via delay length modulation
  - Diffusion control via AP feedback
- **Reference:** Classic spring reverb algorithms (Schroeder, Moorer)

#### 1.2 Plate Engine
- **Status:** ❌ Stub
- **Requirements:**
  - 8-line FDN (Feedback Delay Network)
  - Householder mixing matrix
  - Frequency-dependent damping (HF rolloff)
  - Time scaling via delay lengths
  - Diffusion via AP scattering
- **Reference:** Dattorro plate reverb, Jot reverb

#### 1.3 Room Engine
- **Status:** ❌ Stub
- **Requirements:**
  - Early reflections generator (tap delay network)
  - 4-8 line Schroeder/FDN tail
  - Room size parameter (delay scaling)
  - Diffusion control
  - Depth parameter (early/late balance)
- **Reference:** Moorer reverb, Gardner reverb

#### 1.4 Hall Engine
- **Status:** ❌ Stub
- **Requirements:**
  - 16-line FDN for long tails
  - LF-weighted decay (low-frequency emphasis)
  - Soft HF damping
  - Large space simulation
  - Time scaling
- **Reference:** Jot reverb, Valhalla algorithms

#### 1.5 Convolution Engine Enhancements
- **Status:** ⚠️ Partial
- **Requirements:**
  - True-stereo IR support (4-channel: LL, LR, RL, RR)
  - IR format auto-detection (mono/stereo/4ch)
  - Time scaling (via resampling or convolution length)
  - Latency reporting to host
  - IR trimming and normalization

### Phase 2: Preset System (Priority: HIGH)
**Goal:** Full preset save/load with IR persistence  
**Estimated Time:** 1-2 weeks

#### 2.1 Preset Serialization
- JSON format (`.ambipreset`)
- Save: APVTS state + IR path + metadata
- Load: Restore all parameters + load IR if path valid
- Error handling for missing IRs

#### 2.2 Preset Browser UI
- File browser component
- Preset list with preview
- Load/Save/Delete actions
- Preset naming and metadata

#### 2.3 IR Management
- IR file browser
- IR path persistence in presets
- IR validation and error messages
- Support for common formats (WAV, AIFF)

### Phase 3: UI Enhancements (Priority: MEDIUM)
**Goal:** Complete user interface  
**Estimated Time:** 2-3 weeks

#### 3.1 Advanced Parameter Drawers
- Per-engine advanced controls
- Collapsible sections
- Engine-specific parameters:
  - Spring: Drip amount, tank sizes
  - Plate: Damping curve, matrix type
  - Room: Early reflection pattern, room size
  - Hall: Decay curve, HF damping
  - IR: Trim start/end, normalization

#### 3.2 IR Loading UI
- File chooser button
- IR info display (channels, length, sample rate)
- IR preview (waveform visualization)
- Drag-and-drop support

#### 3.3 A/B Comparison
- A/B state storage
- Toggle button
- Visual indicator

#### 3.4 Copy/Paste
- Parameter copy/paste
- Preset comparison

#### 3.5 Liquid Glass UI Polish
- Enhanced styling
- Animations
- Visual feedback
- Tooltips

### Phase 4: Advanced Features (Priority: MEDIUM)
**Goal:** Enhanced functionality  
**Estimated Time:** 2-3 weeks

#### 4.1 Predelay
- Separate predelay buffer
- Depth parameter integration
- Early/late split control

#### 4.2 Parameter Improvements
- Depth parameter: early/late balance
- Time scaling: proper implementation per engine
- Width: enhanced M/S processing

#### 4.3 EQ Enhancements
- Adjustable Q for mid band
- 4th band (parametric)
- Frequency controls

#### 4.4 IR Manager (v1.1)
- Favorites system
- Tags/categories
- Search functionality

### Phase 5: Testing & Optimization (Priority: HIGH)
**Goal:** Stability and performance  
**Estimated Time:** 2-3 weeks

#### 5.1 Unit Tests
- Engine algorithm tests
- Parameter range validation
- Edge case handling

#### 5.2 Integration Tests
- Full signal path tests
- Preset save/load tests
- IR loading tests

#### 5.3 Performance Optimization
- CPU usage profiling
- Memory usage optimization
- Real-time safety verification

#### 5.4 Host Compatibility
- Test in major DAWs (Logic, Pro Tools, Reaper, etc.)
- Automation testing
- Preset compatibility

### Phase 6: v2.0 - Dolby Atmos (Priority: FUTURE)
**Goal:** Multichannel support  
**Estimated Time:** 8-12 weeks

#### 6.1 Multibus Architecture
- 7.1.4 channel support
- VST3/AU multibus configuration
- Per-channel processing

#### 6.2 Multichannel Convolution
- HOA (Higher Order Ambisonics) IR support
- HOA→bed decoding
- True-stereo per ear pair

#### 6.3 Binaural Preview
- Headphone binaural rendering
- HRTF integration
- Preview mode toggle

---

## Feature Specifications

### Engine Parameter Mapping

All engines share common parameters but interpret them differently:

| Parameter | IR | Spring | Plate | Room | Hall |
|-----------|----|--------|-------|------|------|
| `timeScale` | IR length scaling | Delay lengths | FDN delays | Room size + delays | FDN delays |
| `width` | M/S processing | Stereo spread | FDN panning | Early reflection width | FDN width |
| `depth` | (unused) | (unused) | (unused) | Early/late balance | Early/late balance |
| `diffusion` | (unused) | AP feedback | AP scattering | AP scattering | AP scattering |
| `modDepth` | (unused) | (unused) | Modulation depth | Modulation depth | Modulation depth |
| `modRate` | (unused) | (unused) | Modulation rate | Modulation rate | Modulation rate |

### Preset Format Specification

```json
{
  "version": "1.0.0",
  "name": "Preset Name",
  "mode": "IR|Spring|Plate|Room|Hall",
  "irPath": "/path/to/ir.wav",  // optional, only for IR mode
  "params": {
    "dryWet": 0.0-100.0,
    "hpHz": 10.0-2000.0,
    "lpHz": 2000.0-22050.0,
    "rtScale": 0.5-2.0,
    "width": 0.0-2.0,
    "depth": 0.0-100.0,
    "diffusion": 0.0-100.0,
    "modDepth": 0.0-100.0,
    "modRate": 0.01-3.0,
    "eqLoGain": -12.0-12.0,
    "eqMidGain": -12.0-12.0,
    "eqHiGain": -12.0-12.0
  },
  "advanced": {  // optional, engine-specific
    // Engine-specific parameters
  }
}
```

### IR Format Support

- **Mono IR**: Single channel, duplicated to stereo
- **Stereo IR**: Standard L/R convolution
- **True-Stereo IR (4ch)**: LL, LR, RL, RR matrix
  - Format: Interleaved or separate files
  - Detection: Channel count in audio file

---

## Technical Debt & Issues

### High Priority

1. **Engine Stubs** - All algorithmic engines need complete rewrite
2. **Missing Predelay** - Architecture specifies it but not implemented
3. **Depth Parameter** - Not utilized in any engine
4. **Preset System** - No save/load implementation

### Medium Priority

1. **True-Stereo IR** - Convolution engine limitation
2. **IR Time Scaling** - Not implemented
3. **Advanced Parameters** - Structure exists but not used
4. **UI Features** - Preset browser, IR loader missing

### Low Priority

1. **LookAndFeel** - Basic styling, needs enhancement
2. **Error Handling** - Limited validation
3. **Documentation** - Code comments sparse
4. **Testing** - No test suite

### Code Quality Issues

1. **Code Duplication**: All engines have identical stub code
2. **Unused Parameters**: Many `juce::ignoreUnused(params)` calls
3. **Magic Numbers**: Hardcoded values (e.g., `0.6f`, `0.4f`)
4. **Missing Validation**: No parameter range checking in engines

---

## Testing Strategy

### Unit Tests

**Engine Tests:**
- Impulse response verification
- Parameter range testing
- Edge cases (zero input, extreme parameters)
- Sample rate changes

**DSP Module Tests:**
- Diffuser: Verify diffusion amount
- ModTail: Verify modulation depth/rate
- MsWidth: Verify width parameter
- OutputEQ: Verify frequency response

### Integration Tests

**Signal Path:**
- End-to-end audio processing
- Dry/wet mixing
- Filter chain
- Engine switching

**Preset System:**
- Save/load roundtrip
- IR path persistence
- Parameter restoration
- Error handling (missing files)

### Performance Tests

- CPU usage at various sample rates
- Memory usage profiling
- Latency measurement
- Real-time safety (no allocations in processBlock)

### Test Framework

- Use JUCE UnitTest framework
- Create test fixtures for engines
- Mock audio buffers
- Automated test runner

---

## Performance Targets

### CPU Usage (per engine, stereo, 48kHz)

| Engine | Target | Notes |
|--------|--------|-------|
| IR | < 5% | Depends on IR length |
| Spring | < 2% | Lightweight |
| Plate | < 3% | FDN complexity |
| Room | < 4% | Early reflections + tail |
| Hall | < 5% | Large FDN |

### Memory Usage

- **Base plugin**: < 50 MB
- **Per IR**: Variable (depends on IR length)
- **Engines**: < 10 MB each

### Latency

- **IR mode**: Variable (IR-dependent, reported to host)
- **Algorithmic modes**: < 10 ms (predelay + processing)

---

## Timeline Estimates

### Phase 1: Core DSP (4-6 weeks)
- Week 1-2: Spring + Plate engines
- Week 3-4: Room + Hall engines
- Week 5-6: Convolution enhancements + testing

### Phase 2: Preset System (1-2 weeks)
- Week 1: Serialization + basic UI
- Week 2: IR management + polish

### Phase 3: UI Enhancements (2-3 weeks)
- Week 1: Advanced drawers + IR loader
- Week 2: A/B + Copy/Paste
- Week 3: UI polish

### Phase 4: Advanced Features (2-3 weeks)
- Week 1: Predelay + parameter improvements
- Week 2: EQ enhancements
- Week 3: IR Manager (v1.1 feature)

### Phase 5: Testing & Optimization (2-3 weeks)
- Week 1: Unit + integration tests
- Week 2: Performance optimization
- Week 3: Host compatibility + bug fixes

### Total Estimated Time: **11-17 weeks** (3-4 months)

### v1.0 Release Target
**Minimum Viable Product:**
- ✅ All engines functional
- ✅ Preset save/load
- ✅ Basic UI complete
- ✅ IR loading
- ✅ Host automation

**Target Date:** 3-4 months from current state

---

## Next Steps (Immediate Actions)

1. **Start with Spring Engine** - Simplest algorithm, good starting point
2. **Implement Preset System** - Critical for usability
3. **Add IR Loading UI** - Essential for IR mode
4. **Create Test Framework** - Establish testing early
5. **Document Engine Algorithms** - Write design docs before implementation

---

## References & Resources

### DSP Algorithms
- Dattorro, J. (1997). "Effect Design Part 1: Reverberator and Other Filters"
- Jot, J-M. (1992). "An Analysis/Synthesis Approach to Artificial Reverberation"
- Moorer, J.A. (1979). "About This Reverberation Business"
- Schroeder, M.R. (1962). "Natural Sounding Artificial Reverberation"

### JUCE Resources
- JUCE DSP Module Documentation
- JUCE Convolution Class
- JUCE AudioProcessorValueTreeState

### Project Documentation
- `docs/ARCHITECTURE.md` - System architecture
- `docs/DSP_DESIGN.md` - DSP design notes
- `docs/BUILD.md` - Build instructions
- `docs/CONTRIBUTING.md` - Contribution guidelines

---

**Document Maintained By:** Development Team  
**Review Cycle:** Weekly during active development  
**Version History:**
- v1.0.0 (2025-01-27): Initial comprehensive roadmap

