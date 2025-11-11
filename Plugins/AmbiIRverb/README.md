# AmbiGlass ConvoVerb

Hybrid convolution + algorithmic reverb (IR/Spring/Plate/Room/Hall) built with JUCE 8 + CMake.
Loads Ambi‑Alice IRs but also sounds great without IRs. Ships as VST3/AU.

- Version: 1.0.0 (scaffold) — 2025-11-11
- Company: Flyover Studios
- License: MIT

## Key Features
- True‑stereo convolution (mono/stereo/4‑ch true‑stereo IR)
- Algorithmic engines: Spring, Plate, Room, Hall
- Shared controls: Time, Width, Depth, Diffusion, Mod Depth/Rate
- Pre HP/LP, Output Parametric EQ (3‑band), Dry/Wet
- Preset save/load (.ambipreset JSON), host automation
- Liquid Glass UI styling
- Clear v2 path to Dolby Atmos (7.1.4)

## Build (macOS + Windows)
1. Install CMake 3.22+ and a C++20 toolchain (Xcode 14+/VS2022).
2. (Option A) Bring your own JUCE submodule at ./JUCE
3. (Option B) Use FetchContent (default, see CMakeLists.txt).

```bash
cmake -B build -G "Xcode"        # macOS
cmake --build build --config Release

cmake -B build -G "Visual Studio 17 2022"   # Windows
cmake --build build --config Release
```

On first config, CMake will fetch JUCE automatically unless ./JUCE exists.

## Install
- macOS: AU in ~/Library/Audio/Plug-Ins/Components/, VST3 in ~/Library/Audio/Plug-Ins/VST3/.
- Windows: VST3 will be placed in your user VST3 directory by default JUCE behaviors.

## Docs
- See docs/BUILD.md, docs/DSP_DESIGN.md, docs/ARCHITECTURE.md, docs/ROADMAP.md.
- Cursor context lives in .cursor/.

## Folder Map
```
AmbiGlassConvoVerb/
  CMakeLists.txt
  Source/
  Presets/
  docs/
  .cursor/
  JUCE/                 # optional: submodule placeholder (or auto-fetched)
```
