# Build Guide

## Prereqs
- CMake 3.22+
- C++20 toolchain
- macOS: Xcode 14+ recommended
- Windows: Visual Studio 2022

## Get JUCE
- Option A: `git submodule add https://github.com/juce-framework/JUCE JUCE`
- Option B: do nothing; CMake FetchContent pulls JUCE 8.0.0

## Configure & Build
```bash
cmake -B build -G "Xcode"
cmake --build build --config Release
```

## Install Locations
- AU: `~/Library/Audio/Plug-Ins/Components/`
- VST3: `~/Library/Audio/Plug-Ins/VST3/` (macOS) / `%PROGRAMFILES%/Common Files/VST3` (Windows)
