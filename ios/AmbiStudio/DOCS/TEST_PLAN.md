# Test Plan

## Smoke
- App builds on macOS 14 and iPadOS 17 (simulator for UI, device for audio).

## Audio I/O
- Detect 4+ channel interface, record 4-ch buffer, meter motion seen.
- Files created in temp dir; lengths match session time.

## A→B
- Inject synthetic channel impulses; verify expected W/Y/Z/X output.

## IR
- Offline: generate sweep, convolve with test IR, deconvolve → peak aligns at 0±1 samples.

## Calibration
- Loopback: inserts known delay; algorithm estimates within ±1 ms.
