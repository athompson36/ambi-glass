# UI Guide (Liquid Glass)

**Updated:** 2025-11-11

## Main Views

- **Record**: pick input device, start/stop record, watch glass meters (cyan→purple at peaks).
- **Measure IR**: choose sweep, run measurement (output selection to be wired).
- **Transcode**: drag 4 mono WAVs → export AmbiX / FuMa / stems (stubs now).
- **Calibrate**: loopback test button; shows status and stores profile.
- **Settings**: high‑contrast toggle, advanced DSP toggles.

## IR Reverb Audition (IRTestView)

The IR Test view provides real-time impulse response audition capabilities:

- **Load IR**: Load impulse response files (WAV, AIFF) for testing
- **Wet/Dry Control**: Adjust the reverb mix from 0% (dry) to 100% (wet)
- **Start/Stop**: Control real-time audio processing
- **Latency Display**: Monitor I/O latency in milliseconds

**Usage:**
1. Load an IR file (typically from IR measurement or external source)
2. Adjust wet/dry mix to desired level
3. Press Start to begin real-time convolution
4. Monitor latency for performance assessment

This view uses Core Audio's `AVAudioUnitConvolution` for real-time processing. For full plugin functionality, build the AmbiIRverb JUCE plugin (see `DOCS/PLUGIN_INTEGRATION.md`).
