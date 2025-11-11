#pragma once
#include "HybridVerb.h"
#include <JuceHeader.h>

enum class IRFormat { Mono, Stereo, TrueStereo };

class IRConvolutionEngine : public IReverbEngine
{
public:
    IRConvolutionEngine();
    void prepare(const juce::dsp::ProcessSpec& spec) override;
    void reset() override;
    void setParams(const EngineParams& p) override { params = p; updateTimeScale(); }
    void process(juce::AudioBuffer<float>& buffer) override;

    bool loadIR(const juce::File& file);
    int getLatencySamples() const;
    IRFormat getFormat() const { return format; }
    juce::String getIRInfo() const { return irInfo; }

private:
    IRFormat detectIRFormat(juce::AudioFormatReader* reader);
    void updateTimeScale();
    void loadTrueStereoIR(juce::AudioFormatReader* reader);
    
    EngineParams params;
    juce::dsp::ProcessSpec spec;
    
    // Standard stereo convolution
    juce::dsp::Convolution conv;
    
    // True-stereo convolution (4 channels: LL, LR, RL, RR)
    juce::dsp::Convolution convLL, convLR, convRL, convRR;
    
    IRFormat format = IRFormat::Stereo;
    bool trueStereoMode = false;
    
    // Time scaling
    float currentTimeScale = 1.0f;
    juce::AudioBuffer<float> irBuffer;  // Original IR for time scaling
    double irSampleRate = 48000.0;
    
    // Info
    juce::String irInfo;
};
