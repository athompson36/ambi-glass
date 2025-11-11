#pragma once
#include "HybridVerb.h"
#include <JuceHeader.h>

class RoomEngine : public IReverbEngine {
public:
    RoomEngine();
    void prepare(const juce::dsp::ProcessSpec& spec) override;
    void reset() override;
    void setParams(const EngineParams& p) override { params = p; updateParameters(); }
    void process(juce::AudioBuffer<float>& buffer) override;

private:
    struct EarlyReflection {
        std::vector<float> delayLine;
        int writePos = 0;
        int delaySamples = 0;
        float gain = 1.0f;
        float pan = 0.0f;  // -1.0 (left) to 1.0 (right)
        
        void prepare(int delayMs, double sampleRate, int maxSize) {
            delaySamples = static_cast<int>(delayMs * sampleRate / 1000.0);
            delayLine.resize(maxSize);
            std::fill(delayLine.begin(), delayLine.end(), 0.0f);
            writePos = 0;
        }
        
        float read() const {
            int readPos = (writePos - delaySamples + static_cast<int>(delayLine.size())) % static_cast<int>(delayLine.size());
            return delayLine[readPos];
        }
        
        void write(float sample) {
            delayLine[writePos] = sample;
            writePos = (writePos + 1) % static_cast<int>(delayLine.size());
        }
    };
    
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
    
    void initializeEarlyReflections(double sampleRate, float roomSize);
    void updateParameters();
    void processEarlyReflections(juce::AudioBuffer<float>& buffer, float gain);
    void processLateReverb(juce::AudioBuffer<float>& buffer, float gain);
    
    EngineParams params;
    double sampleRate = 48000.0;
    
    // Early reflections
    static constexpr int numEarlyReflections = 8;
    std::array<EarlyReflection, numEarlyReflections> earlyReflections;
    float roomSizeMs = 20.0f;  // Base room size in ms
    
    // Late reverb (4-line FDN)
    static constexpr int numLateLines = 4;
    std::array<DelayLine, numLateLines> lateDelays;
    std::array<int, numLateLines> baseLateDelays;
    
    // Mixing matrix for late reverb (simple Hadamard-like)
    std::array<std::array<float, numLateLines>, numLateLines> mixingMatrix;
    
    float feedbackGain = 0.7f;
    float modPhase = 0.0f;
};
