# IR Measurement Guide

1. Connect your output(s) to the loudspeaker(s); connect inputs (Ambi-Alice or reference mic) to the interface.
2. In **Calibrate**, run Loopback so the app knows latency and channel gains.
3. In **Measure IR**:
   - Choose sweep length (8–20 s) and band (20–20,000 Hz typical).
   - Select output channels (e.g., 1–2 for L/R, 3 for sub).
   - Press *Generate Sweep & Measure*.
4. After capture, the app deconvolves with the inverse sweep and exports IR files:
   - **Mono** (single mic), **Stereo**, **True-stereo** (4 ch), **FOA IR** (B‑format 4 ch).
5. Import IRs into your convolution reverb or DAW.
