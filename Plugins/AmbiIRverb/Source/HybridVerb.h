#pragma once
#include <JuceHeader.h>

enum class ReverbMode { IR, Spring, Plate, Room, Hall };

struct EngineParams
{
    float timeScale { 1.0f };
    float width { 1.0f };
    float depth { 0.5f };
    float modDepth { 0.1f };
    float modRateHz { 0.3f };
    juce::NamedValueSet advanced;
};

struct IReverbEngine {
    virtual ~IReverbEngine() = default;
    virtual void prepare(const juce::dsp::ProcessSpec&) = 0;
    virtual void reset() = 0;
    virtual void setParams(const EngineParams&) = 0;
    virtual void process(juce::AudioBuffer<float>&) = 0;
};

class IRConvolutionEngine; class SpringEngine; class PlateEngine; class RoomEngine; class HallEngine;

class HybridVerb
{
public:
    void prepare(const juce::dsp::ProcessSpec&);
    void setMode(ReverbMode m) { mode = m; }
    void setParams(const EngineParams& p) { params = p; }
    void process(juce::AudioBuffer<float>&);
    
    // IR-specific methods
    bool loadIR(const juce::File& file);
    int getIRLatency() const;

private:
    ReverbMode mode { ReverbMode::IR };
    std::unique_ptr<IReverbEngine> ir, spring, plate, room, hall;
    EngineParams params;
};
