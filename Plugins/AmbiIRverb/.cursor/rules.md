# Cursor MCP Rules — AmbiGlass ConvoVerb

- Prefer modern JUCE 8 APIs and CMake.
- No blocking calls in audio thread.
- Engines must be switchable at runtime without click/pop.
- When mode==IR, report convolution latency to host; others zero.
- Keep parameter mapping consistent across engines (Time/Width/Depth/Diffusion/Mod).
- Place engine‑specific params behind `advanced` section.
- Enforce denormal suppression on feedback loops.
