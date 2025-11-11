#pragma once
#include "HybridVerb.h"
#include <JuceHeader.h>

class HallEngine : public IReverbEngine {
public:
    HallEngine();
    void prepare(const juce::dsp::ProcessSpec& spec) override;
    void reset() override;
    void setParams(const EngineParams& p) override { params = p; updateParameters(); }
    void process(juce::AudioBuffer<float>& buffer) override;

private:
    struct DelayLine {
        std::vector<float> buffer;
        int writePos = 0;
        int baseDelaySamples = 0;
        float decayGain = 1.0f;  // Per-line decay (LF-weighted)
        
        void prepare(int delaySamples, int maxSize) {
            baseDelaySamples = delaySamples;
            buffer.resize(maxSize);
            std::fill(buffer.begin(), buffer.end(), 0.0f);
            writePos = 0;
        }
        
        float read(int delaySamples) const {
            int readPos = (writePos - delaySamples + static_cast<int>(buffer.size())) % static_cast<int>(buffer.size());
            return buffer[readPos];
        }
        
        void write(float sample) {
            buffer[writePos] = sample;
            writePos = (writePos + 1) % static_cast<int>(buffer.size());
        }
    };
    
    void initializeHouseholderMatrix();
    void initializeDecayTimes(float baseRT60);
    void updateParameters();
    
    EngineParams params;
    double sampleRate = 48000.0;
    
    // 16-line FDN
    static constexpr int numLines = 16;
    std::array<DelayLine, numLines> delays;
    std::array<int, numLines> baseDelaySamples;
    std::array<float, numLines> decayGains;  // LF-weighted decay
    
    // Householder mixing matrix (16x16)
    std::array<std::array<float, numLines>, numLines> mixingMatrix;
    
    // Soft HF damping filters
    std::array<juce::dsp::IIR::Filter<float>, numLines> dampingFilters;
    std::array<juce::dsp::IIR::Coefficients<float>::Ptr, numLines> dampingCoeffs;
    
    // Feedback gain (controlled by diffusion)
    float feedbackGain = 0.75f;
    
    // Modulation
    float modPhase = 0.0f;
    
    // Base RT60 (scaled by timeScale)
    float baseRT60 = 3.0f;  // 3 seconds base
};
