# Architecture

```
Audio In
 ├─ Dry path ───────────────┐
 └─ Pre (HP/LP → Input Diffusion → Predelay)
         │
         ├─ IR Convolver
         ├─ Spring Engine
         ├─ Plate Engine
         ├─ Room Engine
         └─ Hall Engine
               │
         Late Mod → Output EQ → Width (M/S)
               │
         Dry/Wet Crossmix → Out
```

- Engines implement a common IReverbEngine interface.
- HybridVerb selects and drives the active engine.
- Presets stored as JSON (.ambipreset) via APVTS snapshot + IR path.
- UI is JUCE‑based with a segmented control for Mode and an Advanced drawer per engine.
