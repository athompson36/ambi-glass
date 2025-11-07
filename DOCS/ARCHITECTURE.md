# AmbiGlass Architecture

**Updated:** 2025-11-06

AmbiGlass is a SwiftUI universal app targeting macOS/iPadOS for 4‑channel **Ambi‑Alice** capture, ambisonic conversion, IR measurement, and batch transcoding.

## Modules

- **Audio/** — Core Audio / AVAudioEngine capture & device plumbing
  - `AudioDeviceManager.swift` — enumerate inputs, present device list (iPad via AVAudioSession; mac via default).
  - `RecorderEngine.swift` — 4‑ch capture, writers, peak meters.
- **DSP/** — math & transforms
  - `AmbisonicsDSP.swift` — A‑format → FOA B‑format (AmbiX/FuMa) matrix.
  - `IRKit.swift` — ESS sweep generator and (to be implemented) deconvolution.
  - `CalibrationKit.swift` — loopback latency & gain measurement scaffolding.
- **Transcode/** — imports/exports
  - `Transcoder.swift` — drag‑drop of 4 mono WAVs, AmbiX export stub.
- **Theme/** — Liquid Glass UI tokens and components.
- **UI/** — feature views (Record, Measure IR, Transcode, Calibration, Settings).
- **Resources/Presets/** — mic profiles and defaults (e.g., `AmbiAlice_v1.json`).

## Data Flow

```
[CoreAudio 4ch] -> RecorderEngine (A-format)
  -> file writer (A-format safety)
  -> AmbisonicsDSP (A->B) -> file writer (B-format AmbiX)
  -> (future) Binaural monitor
```

**IR measurement:** `IRKit` generates ESS → routes to selected outputs → captures inputs → FFT deconvolution (planned) → exports IRs (mono/stereo/FOA).

## Profiles

- **MicProfile**: A→B matrix (4×4), ordering, orientation (yaw/pitch/roll), per‑capsule trims.
- **InterfaceProfile**: sample rate, buffer, measured I/O latency, channel gain offsets, ripple summary.
