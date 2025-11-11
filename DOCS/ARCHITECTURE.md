# AmbiGlass Architecture

**Updated:** 2025-11-11

AmbiGlass is a SwiftUI universal app targeting macOS/iPadOS for 4‑channel **Ambi‑Alice** capture, ambisonic conversion, IR measurement, batch transcoding, and integrated reverb processing via **AmbiIRverb** plugin.

## Modules

- **Audio/** — Core Audio / AVAudioEngine capture & device plumbing
  - `AudioDeviceManager.swift` — enumerate inputs, present device list (iPad via AVAudioSession; mac via default).
  - `RecorderEngine.swift` — 4‑ch capture, writers, peak meters.
- **DSP/** — math & transforms
  - `AmbisonicsDSP.swift` — A‑format → FOA B‑format (AmbiX/FuMa) matrix.
  - `IRKit.swift` — ESS sweep generator and FFT-based deconvolution with windowing.
  - `CalibrationKit.swift` — loopback latency & gain measurement with auto-apply.
- **Transcode/** — imports/exports
  - `Transcoder.swift` — drag‑drop of 4 mono WAVs, multi-format export (AmbiX, FuMa, Stereo, 5.1, 7.1, Binaural).
- **Theme/** — Liquid Glass UI tokens and components.
- **UI/** — feature views (Record, Measure IR, Transcode, Calibration, Settings, IRTest).
  - `IRTestView.swift` — SwiftUI view for auditioning impulse responses with reverb.
  - `IRTestHost.swift` — AVAudioEngine host for real-time IR convolution.
- **Plugins/AmbiIRverb/** — JUCE plugin source code
  - Hybrid convolution + algorithmic reverb (Spring, Plate, Room, Hall).
  - VST3/AU plugin format.
  - See `Plugins/AmbiIRverb/docs/` for plugin architecture.
- **Resources/Presets/** — mic profiles, reverb presets, and defaults
  - Mic profiles: `AmbiAlice_v1.json`
  - Reverb presets: `.ambipreset` files (Hall, Plate, Room, Spring, IR presets)

## Data Flow

### Recording Pipeline
```
[CoreAudio 4ch] -> RecorderEngine (A-format)
  -> file writer (A-format safety)
  -> AmbisonicsDSP (A->B) -> file writer (B-format AmbiX)
  -> (future) Binaural monitor
```

**IR measurement:** `IRKit` generates ESS → routes to selected outputs → captures inputs → FFT deconvolution with peak alignment and windowing → exports IRs (mono/stereo/true-stereo/FOA).

### IR Reverb Audition Pipeline
```
[Audio Input] -> IRTestHost (AVAudioEngine)
  -> AVAudioUnitConvolution (loads IR)
  -> Wet/Dry mix control
  -> Audio Output
```

**IR Test View:** `IRTestView` provides a SwiftUI interface to load IR files, control wet/dry mix, and monitor I/O latency in real-time.

### AmbiIRverb Plugin Architecture
```
Audio In
 ├─ Dry path ───────────────┐
 └─ Pre (HP/LP → Input Diffusion → Predelay)
         │
         ├─ IR Convolver (ConvoEngine)
         ├─ Spring Engine
         ├─ Plate Engine
         ├─ Room Engine
         └─ Hall Engine
               │
         Late Mod → Output EQ → Width (M/S)
               │
         Dry/Wet Crossmix → Out
```

**Plugin Integration:** The AmbiIRverb JUCE plugin source is included in `Plugins/AmbiIRverb/` and can be built as a standalone VST3/AU plugin. The SwiftUI app includes `IRTestView` for testing IRs using Core Audio's convolution unit, which provides similar functionality for audition purposes.

## Profiles

- **MicProfile**: A→B matrix (4×4), ordering, orientation (yaw/pitch/roll), per‑capsule trims.
- **InterfaceProfile**: sample rate, buffer, measured I/O latency, channel gain offsets, ripple summary.
- **ReverbPreset** (`.ambipreset`): JSON format storing AmbiIRverb plugin parameters, IR paths, and engine mode (IR/Spring/Plate/Room/Hall). See `Plugins/AmbiIRverb/docs/` for preset format details.
