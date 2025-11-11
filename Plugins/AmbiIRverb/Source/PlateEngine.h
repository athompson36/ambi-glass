#pragma once
#include "HybridVerb.h"
#include <JuceHeader.h>

class PlateEngine : public IReverbEngine {
public:
    PlateEngine();
    void prepare(const juce::dsp::ProcessSpec& spec) override;
    void reset() override;
    void setParams(const EngineParams& p) override { params = p; updateParameters(); }
    void process(juce::AudioBuffer<float>& buffer) override;

private:
    struct DelayLine {
        std::vector<float> buffer;
        int writePos = 0;
        int baseDelaySamples = 0;
        
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
    void updateParameters();
    
    EngineParams params;
    double sampleRate = 48000.0;
    
    // 8-line FDN
    static constexpr int numLines = 8;
    std::array<DelayLine, numLines> delays;
    std::array<int, numLines> baseDelaySamples;
    
    // Householder mixing matrix
    std::array<std::array<float, numLines>, numLines> mixingMatrix;
    
    // Frequency-dependent damping filters
    std::array<juce::dsp::IIR::Filter<float>, numLines> dampingFilters;
    std::array<juce::dsp::IIR::Coefficients<float>::Ptr, numLines> dampingCoeffs;
    
    // Feedback gain (controlled by diffusion)
    float feedbackGain = 0.7f;
    
    // Modulation
    float modPhase = 0.0f;
};
