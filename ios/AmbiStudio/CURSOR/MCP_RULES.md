# MCP_RULES.md — AmbiGlass (Cursor)

## Golden Rules
- Never push uncompiled code. Run-build before PR.
- Keep AVFoundation (I/O) separate from DSP math (pure functions).
- Prefer Accelerate (vDSP) over hand loops where practical.
- Add unit tests for DSP transforms (impulse, sine, pink noise).

## Repo Structure Guardrails
- Audio/ : Device + Engine only. No math here.
- DSP/   : Pure math, no UI/AVFoundation. Provide OS-agnostic tests when possible.
- Transcode/ : File I/O, channel maps, exporting.
- UI/    : SwiftUI only. Business logic belongs in modules.
- Theme/ : Liquid Glass tokens & components only.

## Review Checklist
- [ ] Channel ordering documented (AmbiX vs FuMa).
- [ ] Sample rate and buffer size plumbed from a single source of truth.
- [ ] No blocking calls on audio thread; use ring buffers or taps responsibly.
- [ ] File writers closed on stop; errors surfaced to UI.
- [ ] IR deconvolution windowing and normalization tested with known IR.

## Naming Conventions
- Types: PascalCase; functions: camelCase; constants: lowerCamelCase.
- Files named after primary type; one public type per file.

## Security / Privacy
- No unsolicited network traffic. All processing local.
- Microphone/camera usage strings present in Info.plist.

## TODO Ladders
- v0.1: Wire A→B with real matrix; AmbiX export; drag‑drop flow e2e.
- v0.2: FuMa export; FOA → stereo/5.1/7.1 decoders.
- v0.3: ESS deconvolution; IR exports; loopback calibration.
- v0.4: Mic cal loader; SOFA binaural monitor.
