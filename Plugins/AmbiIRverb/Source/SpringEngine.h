#pragma once
#include "HybridVerb.h"
#include <JuceHeader.h>

class SpringEngine : public IReverbEngine {
public:
    SpringEngine();
    void prepare(const juce::dsp::ProcessSpec& spec) override;
    void reset() override;
    void setParams(const EngineParams& p) override { params = p; updateParameters(); }
    void process(juce::AudioBuffer<float>& buffer) override;

private:
    struct AllpassStage {
        std::vector<float> delayLine;
        int writePos = 0;
        int delayLength = 0;
        float feedback = 0.4f;
        
        void prepare(int maxDelaySamples, int delay, double sampleRate) {
            delayLength = static_cast<int>(delay * sampleRate / 1000.0);  // delay in ms
            delayLine.resize(juce::jmax(maxDelaySamples, delayLength * 2));
            std::fill(delayLine.begin(), delayLine.end(), 0.0f);
            writePos = 0;
        }
        
        float process(float input) {
            int readPos = (writePos - delayLength + static_cast<int>(delayLine.size())) % static_cast<int>(delayLine.size());
            float delayed = delayLine[readPos];
            float output = delayed - feedback * input;
            delayLine[writePos] = input + feedback * output;
            writePos = (writePos + 1) % static_cast<int>(delayLine.size());
            return output;
        }
        
        void setFeedback(float fb) { feedback = juce::jlimit(0.0f, 0.9f, fb); }
    };
    
    struct DelayTank {
        std::vector<float> delayLine;
        int writePos = 0;
        int baseDelaySamples = 0;
        float feedbackGain = 0.7f;
        float dampingCoeff = 0.0f;
        float lastSample = 0.0f;  // For simple LP damping
        
        void prepare(int delayMs, double sampleRate) {
            baseDelaySamples = static_cast<int>(delayMs * sampleRate / 1000.0);
            int bufferSize = static_cast<int>(sampleRate * 0.6);  // 600ms max
            delayLine.resize(bufferSize);
            std::fill(delayLine.begin(), delayLine.end(), 0.0f);
            writePos = 0;
            lastSample = 0.0f;
        }
        
        float process(float input, float timeScale, float damping) {
            // Update damping (simple 1-pole LP)
            dampingCoeff = juce::jlimit(0.0f, 0.95f, damping);
            
            // Calculate scaled delay
            int delaySamples = static_cast<int>(baseDelaySamples * timeScale);
            delaySamples = juce::jlimit(1, static_cast<int>(delayLine.size()) - 1, delaySamples);
            
            // Read from delay
            int readPos = (writePos - delaySamples + static_cast<int>(delayLine.size())) % static_cast<int>(delayLine.size());
            float output = delayLine[readPos];
            
            // Apply damping (simple 1-pole LP filter)
            lastSample = output * (1.0f - dampingCoeff) + lastSample * dampingCoeff;
            output = lastSample;
            
            // Write feedback
            delayLine[writePos] = input + output * feedbackGain;
            writePos = (writePos + 1) % static_cast<int>(delayLine.size());
            
            return output;
        }
    };
    
    void updateParameters();
    float applyDrip(float input, float amount);
    
    EngineParams params;
    double sampleRate = 48000.0;
    
    // Dispersive allpass ladder (6 stages)
    static constexpr int numAPStages = 6;
    std::array<AllpassStage, numAPStages> apStages;
    std::array<int, numAPStages> apDelaysMs = { 1, 3, 5, 7, 11, 13 };  // Prime numbers for decorrelation
    
    // Delay tanks (2 parallel for stereo)
    static constexpr int numTanks = 2;
    std::array<DelayTank, numTanks> tanks;
    std::array<int, numTanks> tankDelaysMs = { 250, 300 };  // Different lengths for stereo spread
    
    // Modulation for optional movement
    float modPhase = 0.0f;
    
    // Drip effect
    float dripAmount = 0.0f;
};
