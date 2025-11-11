# Contributing

- Use C++20, follow JUCE style where practical.
- Keep real‑time paths lock‑free.
- Avoid allocations in processBlock.
- Use dsp::ProcessSpec for prepare, honor sample‑rate changes.
- Ensure parameters are thread‑safe (APVTS attachments).

## Testing
- Add lightweight buffer tests under tests/.
