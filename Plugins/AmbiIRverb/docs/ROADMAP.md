# Roadmap

> **Note:** For comprehensive development planning, see [DEVELOPMENT_ROADMAP.md](./DEVELOPMENT_ROADMAP.md)  
> For current implementation status, see [CURRENT_STATE.md](./CURRENT_STATE.md)

## v1.0 (this scaffold) - **IN PROGRESS**
- ✅ Hybrid IR + Algorithmic engines (structure complete, algorithms need implementation)
- ✅ Host automation for all visible controls
- ⚠️ Preset save/load (format defined, implementation needed)
- ⚠️ Liquid Glass UI base (basic styling, needs enhancement)

**Status:** ~25% complete. Core infrastructure ready, DSP algorithms need implementation.

## v1.1 - **PLANNED**
- IR Manager (favorites/tags)
- Adjustable EQ Q and 4th band
- Early/Late split control
- A/B, Copy/Paste

## v2.0 (Dolby Atmos) - **FUTURE**
- 7.1.4 multibus support (VST3/AU)
- Multichannel convolution
- HOA→bed decode option
- Binaural preview (headphones)

---

## Quick Status

**Completed:**
- Build system, parameter management, audio pipeline structure
- DSP utilities (Diffuser, ModTail, MsWidth, OutputEQ)
- Basic UI layout

**In Progress:**
- Algorithmic reverb engines (Spring, Plate, Room, Hall) - all stubs
- Convolution engine - needs true-stereo support
- Preset system - needs implementation
- UI features - preset browser, IR loader, advanced drawers

**See [DEVELOPMENT_ROADMAP.md](./DEVELOPMENT_ROADMAP.md) for detailed phase breakdown and timeline.**
