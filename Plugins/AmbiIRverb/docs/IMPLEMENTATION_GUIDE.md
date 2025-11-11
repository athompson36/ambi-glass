# Implementation Guide

**Purpose:** Technical specifications and implementation details for missing features  
**Audience:** Developers implementing features  
**Last Updated:** 2025-01-27

---

## Table of Contents

1. [Engine Algorithm Implementation](#engine-algorithm-implementation)
2. [Preset System Implementation](#preset-system-implementation)
3. [Convolution Engine Enhancements](#convolution-engine-enhancements)
4. [UI Component Implementation](#ui-component-implementation)
5. [DSP Module Enhancements](#dsp-module-enhancements)

---

## Engine Algorithm Implementation

### Spring Engine

#### Algorithm Overview
Spring reverb simulates mechanical spring reverb units using dispersive allpass filters and delay tanks.

#### Implementation Steps

1. **Dispersive Allpass Ladder**
```cpp
class SpringEngine : public IReverbEngine {
private:
    struct AllpassStage {
        std::vector<float> delayLine;
        int writePos = 0;
        float feedback = 0.4f;
        
        float process(float input) {
            int readPos = (writePos - delayLength + delayLine.size()) % delayLine.size();
            float delayed = delayLine[readPos];
            float output = delayed - feedback * input;
            delayLine[writePos] = input + feedback * output;
            writePos = (writePos + 1) % delayLine.size();
            return output;
        }
    };
    
    std::array<AllpassStage, 6> apStages;  // 6-stage ladder
    std::array<DelayLine, 2> tanks;        // 2 parallel tanks
};
```

2. **Delay Tank Structure**
```cpp
struct DelayTank {
    std::vector<float> delayLine;
    int writePos = 0;
    float feedbackGain = 0.7f;
    float damping = 0.3f;  // HF damping
    
    float process(float input) {
        // Read from delay
        int delayLength = static_cast<int>(delayLine.size() * params.timeScale);
        int readPos = (writePos - delayLength + delayLine.size()) % delayLine.size();
        float output = delayLine[readPos];
        
        // Apply damping (simple LP filter)
        output = applyDamping(output, damping);
        
        // Write feedback
        delayLine[writePos] = input + output * feedbackGain;
        writePos = (writePos + 1) % delayLine.size();
        
        return output;
    }
};
```

3. **Parameter Mapping**
- `timeScale`: Modulate delay lengths in tanks
- `diffusion`: Control AP feedback amount (0.3-0.7)
- `width`: Stereo spread via different tank lengths
- `modDepth/modRate`: Optional modulation on delay lengths

4. **Optional "Drip" Effect**
```cpp
float applyDrip(float input, float amount) {
    if (amount < 0.01f) return input;
    // Nonlinearity: soft saturation + slight distortion
    float saturated = std::tanh(input * (1.0f + amount * 2.0f));
    return input * (1.0f - amount) + saturated * amount;
}
```

#### Reference Implementation
- Moorer, J.A. "About This Reverberation Business" (1979)
- Typical delay lengths: 200-500ms per tank
- AP delays: 1-10ms, prime numbers for decorrelation

---

### Plate Engine

#### Algorithm Overview
Plate reverb uses an 8-line Feedback Delay Network (FDN) with Householder mixing matrix.

#### Implementation Steps

1. **FDN Structure**
```cpp
class PlateEngine : public IReverbEngine {
private:
    struct DelayLine {
        std::vector<float> buffer;
        int writePos = 0;
        float feedback = 0.0f;
        
        float read(int delaySamples) const {
            int readPos = (writePos - delaySamples + buffer.size()) % buffer.size();
            return buffer[readPos];
        }
        
        void write(float sample) {
            buffer[writePos] = sample;
            writePos = (writePos + 1) % buffer.size();
        }
    };
    
    std::array<DelayLine, 8> delays;
    std::array<std::array<float, 8>, 8> mixingMatrix;  // Householder
};
```

2. **Householder Matrix**
```cpp
void initializeHouseholderMatrix() {
    const float scale = 1.0f / std::sqrt(8.0f);
    for (int i = 0; i < 8; ++i) {
        for (int j = 0; j < 8; ++j) {
            if (i == j) {
                mixingMatrix[i][j] = 2.0f * scale - 1.0f;
            } else {
                mixingMatrix[i][j] = 2.0f * scale;
            }
        }
    }
}
```

3. **Frequency-Dependent Damping**
```cpp
struct DampingFilter {
    juce::dsp::IIR::Filter<float> filter;
    
    void update(float sampleRate, float damping) {
        // HF rolloff: higher damping = more HF loss
        float cutoff = 2000.0f + damping * 8000.0f;
        *filter.state = *juce::dsp::IIR::Coefficients<float>::makeLowPass(
            sampleRate, cutoff, 0.707f);
    }
};

std::array<DampingFilter, 8> dampingFilters;
```

4. **Processing Loop**
```cpp
void PlateEngine::process(juce::AudioBuffer<float>& buffer) {
    const int numSamples = buffer.getNumSamples();
    const float timeScale = params.timeScale;
    
    // Calculate delay lengths (prime numbers, scaled by timeScale)
    std::array<int, 8> delayLengths = {
        static_cast<int>(37 * timeScale),
        static_cast<int>(87 * timeScale),
        static_cast<int>(181 * timeScale),
        static_cast<int>(271 * timeScale),
        static_cast<int>(359 * timeScale),
        static_cast<int>(449 * timeScale),
        static_cast<int>(563 * timeScale),
        static_cast<int>(641 * timeScale)
    };
    
    for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
        auto* x = buffer.getWritePointer(ch);
        
        for (int n = 0; n < numSamples; ++n) {
            float input = x[n];
            
            // Read from all delays
            std::array<float, 8> delayed;
            for (int i = 0; i < 8; ++i) {
                delayed[i] = delays[i].read(delayLengths[i]);
                delayed[i] = dampingFilters[i].processSample(delayed[i]);
            }
            
            // Mix through Householder matrix
            std::array<float, 8> mixed;
            for (int i = 0; i < 8; ++i) {
                mixed[i] = 0.0f;
                for (int j = 0; j < 8; ++j) {
                    mixed[i] += mixingMatrix[i][j] * delayed[j];
                }
            }
            
            // Add input and write back
            float output = 0.0f;
            for (int i = 0; i < 8; ++i) {
                delays[i].write(input + mixed[i] * feedbackGain);
                output += mixed[i];
            }
            
            x[n] = input * dryGain + output * wetGain;
        }
    }
}
```

5. **Parameter Mapping**
- `timeScale`: Scale all delay lengths
- `diffusion`: Control feedback gain (0.5-0.9)
- `width`: Stereo panning in mixing
- `modDepth/modRate`: Modulate delay lengths slightly

#### Reference Implementation
- Dattorro, J. "Effect Design Part 1: Reverberator and Other Filters" (1997)
- Typical delays: 30-200ms, prime numbers
- Feedback: 0.6-0.85 for plate character

---

### Room Engine

#### Algorithm Overview
Room reverb combines early reflections (tap delays) with a late reverb tail (FDN).

#### Implementation Steps

1. **Early Reflection Generator**
```cpp
struct EarlyReflection {
    int delaySamples;
    float gain;
    float pan;  // -1.0 (left) to 1.0 (right)
};

class RoomEngine : public IReverbEngine {
private:
    std::vector<EarlyReflection> earlyReflections;
    std::array<DelayLine, 4> lateReverbDelays;  // 4-line FDN
};
```

2. **Early Reflection Pattern**
```cpp
void initializeEarlyReflections(float sampleRate, float roomSize) {
    earlyReflections.clear();
    
    // Generate tap delays based on room size
    // Typical pattern: 5-20ms initial, then decaying taps
    const float baseDelay = roomSize * 0.001f * sampleRate;  // roomSize in ms
    
    earlyReflections = {
        {static_cast<int>(baseDelay * 0.1f), 0.8f, -0.7f},
        {static_cast<int>(baseDelay * 0.3f), 0.6f, 0.5f},
        {static_cast<int>(baseDelay * 0.5f), 0.4f, -0.3f},
        {static_cast<int>(baseDelay * 0.7f), 0.3f, 0.2f},
        {static_cast<int>(baseDelay * 0.9f), 0.2f, -0.1f},
        // ... more taps
    };
}
```

3. **Early/Late Split (Depth Parameter)**
```cpp
void RoomEngine::process(juce::AudioBuffer<float>& buffer) {
    const float depth = params.depth / 100.0f;  // 0.0 = all early, 1.0 = all late
    const float earlyGain = 1.0f - depth;
    const float lateGain = depth;
    
    // Process early reflections
    processEarlyReflections(buffer, earlyGain);
    
    // Process late reverb
    processLateReverb(buffer, lateGain);
}
```

4. **Late Reverb (4-line FDN)**
```cpp
void processLateReverb(juce::AudioBuffer<float>& buffer, float gain) {
    // Similar to Plate but with 4 lines instead of 8
    // Shorter delays, more diffusion
    std::array<int, 4> delayLengths = {
        static_cast<int>(100 * params.timeScale),
        static_cast<int>(147 * params.timeScale),
        static_cast<int>(199 * params.timeScale),
        static_cast<int>(251 * params.timeScale)
    };
    
    // FDN processing (similar to Plate)
    // ...
}
```

5. **Parameter Mapping**
- `timeScale`: Scale room size and delay lengths
- `depth`: Balance early/late (0 = all early, 1 = all late)
- `diffusion`: Control FDN feedback and AP scattering
- `width`: Stereo spread in early reflections

#### Reference Implementation
- Moorer, J.A. "About This Reverberation Business" (1979)
- Gardner, W.G. "Reverberation Algorithms" (1992)
- Typical room sizes: 5-50ms early reflections

---

### Hall Engine

#### Algorithm Overview
Hall reverb uses a large 16-line FDN with LF-weighted decay and soft HF damping.

#### Implementation Steps

1. **16-Line FDN**
```cpp
class HallEngine : public IReverbEngine {
private:
    std::array<DelayLine, 16> delays;
    std::array<DampingFilter, 16> dampingFilters;
    std::array<float, 16> decayTimes;  // Per-line decay times
};
```

2. **LF-Weighted Decay**
```cpp
void initializeDecayTimes(float baseRT60) {
    // Lower frequencies decay slower (longer RT60)
    for (int i = 0; i < 16; ++i) {
        // Simulate frequency-dependent decay
        float freqFactor = 1.0f + (i / 16.0f) * 0.5f;  // Higher lines = higher freq
        decayTimes[i] = baseRT60 / freqFactor;
    }
}
```

3. **Soft HF Damping**
```cpp
void updateDampingFilters(float sampleRate, float dampingAmount) {
    for (int i = 0; i < 16; ++i) {
        // Higher delay lines get more damping (simulate HF loss)
        float cutoff = 3000.0f + (i / 16.0f) * 5000.0f;
        cutoff *= (1.0f - dampingAmount * 0.5f);  // Reduce with damping
        
        *dampingFilters[i].state = 
            *juce::dsp::IIR::Coefficients<float>::makeLowPass(
                sampleRate, cutoff, 0.5f);  // Soft Q
    }
}
```

4. **Large Space Simulation**
```cpp
void initializeDelayLengths(float timeScale) {
    // Large delays for hall character (100-500ms)
    std::array<int, 16> lengths = {
        static_cast<int>(113 * timeScale),
        static_cast<int>(173 * timeScale),
        static_cast<int>(229 * timeScale),
        static_cast<int>(283 * timeScale),
        static_cast<int>(337 * timeScale),
        static_cast<int>(397 * timeScale),
        static_cast<int>(449 * timeScale),
        static_cast<int>(503 * timeScale),
        static_cast<int>(563 * timeScale),
        static_cast<int>(613 * timeScale),
        static_cast<int>(673 * timeScale),
        static_cast<int>(727 * timeScale),
        static_cast<int>(787 * timeScale),
        static_cast<int>(839 * timeScale),
        static_cast<int>(887 * timeScale),
        static_cast<int>(947 * timeScale)
    };
}
```

5. **Parameter Mapping**
- `timeScale`: Scale all delay lengths and RT60
- `diffusion`: Control FDN feedback
- `width`: Stereo width in mixing matrix
- `modDepth/modRate`: Subtle modulation for movement

#### Reference Implementation
- Jot, J-M. "An Analysis/Synthesis Approach to Artificial Reverberation" (1992)
- Typical delays: 100-500ms for large halls
- RT60: 2-8 seconds for concert halls

---

## Preset System Implementation

### JSON Format

```json
{
  "version": "1.0.0",
  "name": "Preset Name",
  "mode": "IR|Spring|Plate|Room|Hall",
  "irPath": "/absolute/path/to/ir.wav",
  "params": {
    "dryWet": 30.0,
    "hpHz": 30.0,
    "lpHz": 18000.0,
    "rtScale": 1.0,
    "width": 1.0,
    "depth": 50.0,
    "diffusion": 35.0,
    "modDepth": 10.0,
    "modRate": 0.3,
    "eqLoGain": 0.0,
    "eqMidGain": 0.0,
    "eqHiGain": 0.0
  },
  "advanced": {
    // Engine-specific parameters (optional)
  }
}
```

### Implementation

#### 1. Serialization (`FileIO.h/cpp`)

```cpp
// FileIO.h
struct PresetData {
    juce::String name;
    ReverbMode mode;
    juce::String irPath;
    juce::NamedValueSet params;
    juce::NamedValueSet advanced;
};

class PresetManager {
public:
    static bool savePreset(const juce::File& file, const PresetData& data);
    static std::unique_ptr<PresetData> loadPreset(const juce::File& file);
    static juce::Array<juce::File> getPresetFiles();
};
```

#### 2. Save Implementation

```cpp
bool PresetManager::savePreset(const juce::File& file, const PresetData& data) {
    juce::var root;
    root["version"] = "1.0.0";
    root["name"] = data.name;
    
    // Mode
    const char* modeNames[] = { "IR", "Spring", "Plate", "Room", "Hall" };
    root["mode"] = modeNames[static_cast<int>(data.mode)];
    
    // IR path (if applicable)
    if (data.mode == ReverbMode::IR && data.irPath.isNotEmpty()) {
        root["irPath"] = data.irPath;
    }
    
    // Parameters
    juce::var params;
    for (int i = 0; i < data.params.size(); ++i) {
        auto name = data.params.getName(i);
        auto value = data.params[name];
        params[name] = value;
    }
    root["params"] = params;
    
    // Advanced (if present)
    if (data.advanced.size() > 0) {
        juce::var advanced;
        for (int i = 0; i < data.advanced.size(); ++i) {
            auto name = data.advanced.getName(i);
            auto value = data.advanced[name];
            advanced[name] = value;
        }
        root["advanced"] = advanced;
    }
    
    // Write to file
    juce::FileOutputStream stream(file);
    if (stream.openedOk()) {
        juce::JSON::writeToStream(stream, root);
        return true;
    }
    return false;
}
```

#### 3. Load Implementation

```cpp
std::unique_ptr<PresetData> PresetManager::loadPreset(const juce::File& file) {
    if (!file.existsAsFile()) return nullptr;
    
    juce::var root = juce::JSON::parse(file);
    if (!root.isObject()) return nullptr;
    
    auto data = std::make_unique<PresetData>();
    
    // Name
    data->name = root.getProperty("name", "").toString();
    
    // Mode
    juce::String modeStr = root.getProperty("mode", "IR").toString();
    if (modeStr == "Spring") data->mode = ReverbMode::Spring;
    else if (modeStr == "Plate") data->mode = ReverbMode::Plate;
    else if (modeStr == "Room") data->mode = ReverbMode::Room;
    else if (modeStr == "Hall") data->mode = ReverbMode::Hall;
    else data->mode = ReverbMode::IR;
    
    // IR path
    data->irPath = root.getProperty("irPath", "").toString();
    
    // Parameters
    juce::var params = root.getProperty("params", juce::var());
    if (params.isObject()) {
        auto* obj = params.getDynamicObject();
        if (obj != nullptr) {
            auto props = obj->getProperties();
            for (auto& prop : props) {
                data->params.set(prop.name.toString(), prop.value);
            }
        }
    }
    
    // Advanced
    juce::var advanced = root.getProperty("advanced", juce::var());
    if (advanced.isObject()) {
        auto* obj = advanced.getDynamicObject();
        if (obj != nullptr) {
            auto props = obj->getProperties();
            for (auto& prop : props) {
                data->advanced.set(prop.name.toString(), prop.value);
            }
        }
    }
    
    return data;
}
```

#### 4. Integration with PluginProcessor

```cpp
// In PluginProcessor.h
void loadPreset(const juce::File& file);
void savePreset(const juce::File& file);

// In PluginProcessor.cpp
void AmbiGlassConvoVerbAudioProcessor::loadPreset(const juce::File& file) {
    auto data = PresetManager::loadPreset(file);
    if (data == nullptr) return;
    
    // Set mode
    parameters.mode->setValueNotifyingHost(
        parameters.mode->convertTo0to1(static_cast<int>(data->mode)));
    
    // Set parameters
    for (int i = 0; i < data->params.size(); ++i) {
        auto name = data->params.getName(i);
        auto* param = parameters.apvts.getParameter(name);
        if (param != nullptr) {
            float value = static_cast<float>(data->params[name]);
            param->setValueNotifyingHost(param->convertTo0to1(value));
        }
    }
    
    // Load IR if needed
    if (data->mode == ReverbMode::IR && data->irPath.isNotEmpty()) {
        juce::File irFile(data->irPath);
        if (irFile.existsAsFile()) {
            // Get HybridVerb's IR engine and load
            // (Need to expose loadIR method)
        }
    }
}

void AmbiGlassConvoVerbAudioProcessor::savePreset(const juce::File& file) {
    PresetData data;
    data.name = file.getFileNameWithoutExtension();
    data.mode = static_cast<ReverbMode>(parameters.mode->getIndex());
    
    // Copy parameters
    for (auto* param : parameters.apvts.getParameters()) {
        float value = param->getValue();
        data.params.set(param->getName(1024), value);
    }
    
    // Save IR path if in IR mode
    // (Need to store current IR path)
    
    PresetManager::savePreset(file, data);
}
```

---

## Convolution Engine Enhancements

### True-Stereo IR Support

#### 1. IR Format Detection

```cpp
enum class IRFormat { Mono, Stereo, TrueStereo };

IRFormat detectIRFormat(const juce::AudioFormatReader* reader) {
    int numChannels = reader->numChannels;
    if (numChannels == 1) return IRFormat::Mono;
    if (numChannels == 2) return IRFormat::Stereo;
    if (numChannels == 4) return IRFormat::TrueStereo;
    return IRFormat::Stereo;  // Default
}
```

#### 2. True-Stereo Convolution

```cpp
class IRConvolutionEngine : public IReverbEngine {
private:
    juce::dsp::Convolution convLL, convLR, convRL, convRR;
    IRFormat format = IRFormat::Stereo;
    bool trueStereoMode = false;
};

void IRConvolutionEngine::loadIR(const juce::File& file) {
    auto* reader = juce::AudioFormatManager::createReaderFor(file);
    if (reader == nullptr) return;
    
    format = detectIRFormat(reader);
    
    if (format == IRFormat::TrueStereo) {
        // Load 4 channels: LL, LR, RL, RR
        juce::AudioBuffer<float> buffer(4, static_cast<int>(reader->lengthInSamples));
        reader->read(&buffer, 0, buffer.getNumSamples(), 0, true, true);
        
        // Extract channels
        juce::AudioBuffer<float> ll(1, buffer.getNumSamples());
        juce::AudioBuffer<float> lr(1, buffer.getNumSamples());
        juce::AudioBuffer<float> rl(1, buffer.getNumSamples());
        juce::AudioBuffer<float> rr(1, buffer.getNumSamples());
        
        ll.copyFrom(0, 0, buffer, 0, 0, buffer.getNumSamples());
        lr.copyFrom(0, 0, buffer, 1, 0, buffer.getNumSamples());
        rl.copyFrom(0, 0, buffer, 2, 0, buffer.getNumSamples());
        rr.copyFrom(0, 0, buffer, 3, 0, buffer.getNumSamples());
        
        // Load into convolvers
        convLL.loadImpulseResponse(ll, getSampleRate(), ...);
        convLR.loadImpulseResponse(lr, getSampleRate(), ...);
        convRL.loadImpulseResponse(rl, getSampleRate(), ...);
        convRR.loadImpulseResponse(rr, getSampleRate(), ...);
        
        trueStereoMode = true;
    } else {
        // Standard stereo or mono
        conv.loadImpulseResponse(file, ...);
        trueStereoMode = false;
    }
}
```

#### 3. True-Stereo Processing

```cpp
void IRConvolutionEngine::process(juce::AudioBuffer<float>& buffer) {
    if (trueStereoMode) {
        // True-stereo: 4 convolvers
        juce::AudioBuffer<float> tempL(1, buffer.getNumSamples());
        juce::AudioBuffer<float> tempR(1, buffer.getNumSamples());
        
        tempL.copyFrom(0, 0, buffer, 0, 0, buffer.getNumSamples());
        tempR.copyFrom(0, 0, buffer, 1, 0, buffer.getNumSamples());
        
        // Process each channel
        juce::dsp::AudioBlock<float> blockL(tempL);
        juce::dsp::AudioBlock<float> blockR(tempR);
        
        juce::dsp::ProcessContextReplacing<float> ctxL(blockL);
        juce::dsp::ProcessContextReplacing<float> ctxR(blockR);
        
        // Left output = LL*L + LR*R
        auto llOut = convLL.process(ctxL);
        auto lrOut = convLR.process(ctxR);
        
        // Right output = RL*L + RR*R
        auto rlOut = convRL.process(ctxL);
        auto rrOut = convRR.process(ctxR);
        
        // Mix
        buffer.copyFrom(0, 0, llOut, 0, 0, buffer.getNumSamples());
        buffer.addFrom(0, 0, lrOut, 0, 0, buffer.getNumSamples());
        buffer.copyFrom(1, 0, rlOut, 0, 0, buffer.getNumSamples());
        buffer.addFrom(1, 0, rrOut, 0, 0, buffer.getNumSamples());
    } else {
        // Standard stereo
        juce::dsp::AudioBlock<float> block(buffer);
        juce::dsp::ProcessContextReplacing<float> ctx(block);
        conv.process(ctx);
    }
}
```

### Time Scaling

```cpp
void IRConvolutionEngine::setTimeScale(float scale) {
    // Option 1: Resample IR
    if (scale != 1.0f && currentIR.isValid()) {
        // Resample IR buffer
        juce::AudioBuffer<float> resampled;
        // ... resampling code ...
        conv.loadImpulseResponse(resampled, ...);
    }
    
    // Option 2: Truncate/extend (simpler but less accurate)
    // Adjust convolution length
}
```

### Latency Reporting

```cpp
int IRConvolutionEngine::getLatencySamples() const {
    if (trueStereoMode) {
        return convLL.getLatency();
    }
    return conv.getLatency();
}

// In PluginProcessor
int AmbiGlassConvoVerbAudioProcessor::getLatencySamples() const {
    if (parameters.mode->getIndex() == 0) {  // IR mode
        return hybrid.getIRLatency();
    }
    return 0;  // Algorithmic modes have minimal latency
}
```

---

## UI Component Implementation

### Preset Browser

```cpp
class PresetBrowser : public juce::Component {
public:
    PresetBrowser(AmbiGlassConvoVerbAudioProcessor& p) : processor(p) {
        presetList.setModel(this);
        addAndMakeVisible(presetList);
        
        loadButton.onClick = [this] { loadSelectedPreset(); };
        saveButton.onClick = [this] { saveCurrentPreset(); };
        deleteButton.onClick = [this] { deleteSelectedPreset(); };
        
        addAndMakeVisible(loadButton);
        addAndMakeVisible(saveButton);
        addAndMakeVisible(deleteButton);
        
        refreshList();
    }
    
    void refreshList() {
        presets = PresetManager::getPresetFiles();
        presetList.updateContent();
    }
    
private:
    juce::ListBox presetList;
    juce::TextButton loadButton {"Load"};
    juce::TextButton saveButton {"Save"};
    juce::TextButton deleteButton {"Delete"};
    
    juce::Array<juce::File> presets;
    AmbiGlassConvoVerbAudioProcessor& processor;
    
    int getNumRows() override { return presets.size(); }
    void paintListBoxItem(int row, juce::Graphics& g, int width, int height, bool selected) override {
        if (row < presets.size()) {
            g.setColour(selected ? juce::Colours::blue : juce::Colours::white);
            g.drawText(presets[row].getFileNameWithoutExtension(), 4, 0, width-4, height, juce::Justification::left);
        }
    }
    
    void loadSelectedPreset() {
        int selected = presetList.getSelectedRow();
        if (selected >= 0 && selected < presets.size()) {
            processor.loadPreset(presets[selected]);
        }
    }
    
    void saveCurrentPreset() {
        juce::FileChooser chooser("Save Preset", PresetManager::getPresetFolder(), "*.ambipreset");
        if (chooser.browseForFileToSave(true)) {
            processor.savePreset(chooser.getResult());
            refreshList();
        }
    }
};
```

### IR Loader

```cpp
class IRLoader : public juce::Component {
public:
    IRLoader(AmbiGlassConvoVerbAudioProcessor& p) : processor(p) {
        loadButton.onClick = [this] { loadIRFile(); };
        addAndMakeVisible(loadButton);
        
        irInfoLabel.setJustificationType(juce::Justification::left);
        addAndMakeVisible(irInfoLabel);
    }
    
private:
    juce::TextButton loadButton {"Load IR..."};
    juce::Label irInfoLabel;
    AmbiGlassConvoVerbAudioProcessor& processor;
    
    void loadIRFile() {
        juce::FileChooser chooser("Load Impulse Response", {}, "*.wav;*.aiff;*.flac");
        if (chooser.browseForFileToOpen()) {
            auto file = chooser.getResult();
            if (processor.loadIR(file)) {
                // Update info label
                auto* reader = juce::AudioFormatManager::createReaderFor(file);
                if (reader != nullptr) {
                    juce::String info = juce::String(reader->numChannels) + "ch, ";
                    info += juce::String(reader->sampleRate) + "Hz, ";
                    info += juce::String(reader->lengthInSamples / reader->sampleRate, 2) + "s";
                    irInfoLabel.setText(info, juce::dontSendNotification);
                }
            }
        }
    }
};
```

---

## DSP Module Enhancements

### Predelay Implementation

```cpp
class Predelay {
public:
    void prepare(const juce::dsp::ProcessSpec& spec) {
        sampleRate = spec.sampleRate;
        maxDelaySamples = static_cast<int>(0.5 * sampleRate);  // 500ms max
        buffer.setSize(2, maxDelaySamples);
        buffer.clear();
        writePos = 0;
    }
    
    void setDelayMs(float ms) {
        delaySamples = static_cast<int>(ms * 0.001f * sampleRate);
        delaySamples = juce::jlimit(0, maxDelaySamples, delaySamples);
    }
    
    void process(juce::AudioBuffer<float>& buf) {
        const int numSamples = buf.getNumSamples();
        for (int ch = 0; ch < buf.getNumChannels(); ++ch) {
            auto* x = buf.getWritePointer(ch);
            auto* d = buffer.getWritePointer(ch);
            
            for (int n = 0; n < numSamples; ++n) {
                int readPos = (writePos - delaySamples + maxDelaySamples) % maxDelaySamples;
                float delayed = d[readPos];
                d[writePos] = x[n];
                x[n] = delayed;
                writePos = (writePos + 1) % maxDelaySamples;
            }
        }
    }
    
private:
    juce::AudioBuffer<float> buffer;
    int writePos = 0;
    int delaySamples = 0;
    int maxDelaySamples = 0;
    double sampleRate = 48000.0;
};
```

### Enhanced OutputEQ (Q Controls)

```cpp
void OutputEQ::setMidParams(float freq, float q, float gain) {
    midFreq = freq;
    midQ = q;
    midGain = gain;
    update();
}

void OutputEQ::update() {
    // ...
    *mid.state = *juce::dsp::IIR::Coefficients<float>::makePeakFilter(
        fs, midFreq, midQ, juce::Decibels::decibelsToGain(midGain));
    // ...
}
```

---

## Testing Guidelines

### Unit Test Example

```cpp
class SpringEngineTest : public juce::UnitTest {
public:
    SpringEngineTest() : juce::UnitTest("Spring Engine") {}
    
    void runTest() override {
        beginTest("Initialization");
        SpringEngine engine;
        juce::dsp::ProcessSpec spec { 48000.0, 512, 2 };
        engine.prepare(spec);
        
        beginTest("Impulse Response");
        juce::AudioBuffer<float> buffer(2, 512);
        buffer.clear();
        buffer.setSample(0, 0, 1.0f);  // Impulse
        
        EngineParams params;
        params.timeScale = 1.0f;
        engine.setParams(params);
        engine.process(buffer);
        
        // Verify reverb tail
        expect(buffer.getSample(0, 100) != 0.0f, "Should have reverb");
        expect(buffer.getSample(0, 400) < buffer.getSample(0, 100), "Should decay");
    }
};

static SpringEngineTest springEngineTest;
```

---

## Performance Considerations

### Real-Time Safety
- ✅ No allocations in `processBlock()`
- ✅ Pre-allocate all buffers in `prepare()`
- ✅ Use `juce::ScopedNoDenormals` in processing
- ✅ Avoid `std::vector` resizing in audio thread

### CPU Optimization
- Use SIMD where possible (JUCE DSP classes handle this)
- Minimize function calls in inner loops
- Cache frequently accessed values
- Use lookup tables for expensive calculations

### Memory Management
- Pre-allocate delay lines based on max sample rate
- Use `juce::AudioBuffer` for audio data
- Avoid `new/delete` in audio thread

---

**Last Updated:** 2025-01-27  
**Next Review:** After Phase 1 implementation

