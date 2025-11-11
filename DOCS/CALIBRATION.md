# Calibration

## Interface Loopback
- Connect an output to an input with a short cable.
- App plays sweep/MLS and measures:
  - I/O latency (samples/ms)
  - Per-channel gain offsets (dB)
- Saves **InterfaceProfile** with timestamp; applied automatically.

## Mic Calibration
- Load `.cal` or `.txt/.csv`: frequency (Hz), gain (dB).
- Interpolate to session sample rate.
- Apply to reference mic path and (optionally) per-capsule trims.
