# DSP Notes

## A-format → FOA B-format

Ambi‑Alice provides A‑format (capsule signals). Convert to FOA using a 4×4 matrix `M`:
```
B = M · A
```
Default export is **AmbiX (ACN/SN3D)** (W,Y,Z,X). Provide a preset and allow tuning of yaw/pitch/roll and per-capsule trims.

### AmbiX vs FuMa
- **AmbiX (ACN/SN3D)** ordering: ACN 0..3 → (W,Y,Z,X)
- **FuMa** ordering: (W,X,Y,Z) with different normalization (FuMa/MaxN). Add a scaler when exporting FuMa.

## Exponential Sine Sweep (ESS)

Generate sweep with start f0 and end f1, then build an inverse filter for deconvolution. For robust IRs:
- Use >= 8 s sweep for large rooms; 20–20,000 Hz range typical.
- Window/gate post‑deconvolution; normalize to peak=1.0; export 32‑bit float WAV.

## Loopback Calibration

Measure:
- **Latency**: cross‑correlate known sweep vs captured loopback.
- **Per‑channel gain**: pink noise RMS compare.
- **FR ripple**: optional; pink/ESS averaged in octave bands.

Store offsets in **InterfaceProfile** and apply to recordings & IR alignment.
