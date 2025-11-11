#include "RoomEngine.h"
#include <cmath>

RoomEngine::RoomEngine()
{
    params.timeScale = 1.0f;
    params.diffusion = 0.5f;
    params.width = 1.0f;
    params.depth = 50.0f;  // Default: balanced early/late
    params.modDepth = 0.0f;
    params.modRate = 0.3f;
    
    // Initialize simple mixing matrix for late reverb (4x4)
    // Use a simple orthogonal matrix
    mixingMatrix[0] = { 0.5f,  0.5f,  0.5f,  0.5f };
    mixingMatrix[1] = { 0.5f, -0.5f,  0.5f, -0.5f };
    mixingMatrix[2] = { 0.5f,  0.5f, -0.5f, -0.5f };
    mixingMatrix[3] = { 0.5f, -0.5f, -0.5f,  0.5f };
}

void RoomEngine::prepare(const juce::dsp::ProcessSpec& spec)
{
    sampleRate = spec.sampleRate;
    
    // Initialize early reflections
    initializeEarlyReflections(spec.sampleRate, roomSizeMs);
    
    // Prepare late reverb delays (4-line FDN)
    int maxDelaySamples = static_cast<int>(spec.sampleRate * 0.3);  // 300ms max
    int bufferSize = maxDelaySamples * 2;
    
    // Base delays in ms (shorter than plate for room character)
    std::array<int, numLateLines> delayMs = { 100, 147, 199, 251 };
    
    for (size_t i = 0; i < lateDelays.size(); ++i) {
        baseLateDelays[i] = static_cast<int>(delayMs[i] * spec.sampleRate / 1000.0);
        lateDelays[i].prepare(baseLateDelays[i], bufferSize);
    }
    
    reset();
    updateParameters();
}

void RoomEngine::reset()
{
    for (auto& early : earlyReflections) {
        std::fill(early.delayLine.begin(), early.delayLine.end(), 0.0f);
        early.writePos = 0;
    }
    
    for (auto& delay : lateDelays) {
        std::fill(delay.buffer.begin(), delay.buffer.end(), 0.0f);
        delay.writePos = 0;
    }
    
    modPhase = 0.0f;
}

void RoomEngine::initializeEarlyReflections(double sampleRate, float roomSize)
{
    // Generate early reflection pattern
    // Typical room: initial reflections at 5-20ms, then decaying taps
    int maxDelaySamples = static_cast<int>(sampleRate * 0.1);  // 100ms max for early
    
    // Early reflection pattern (delays in ms, gains, panning)
    struct EarlyPattern {
        float delayMs;
        float gain;
        float pan;
    };
    
    std::array<EarlyPattern, numEarlyReflections> pattern = {
        EarlyPattern{ roomSize * 0.1f, 0.8f, -0.7f },
        EarlyPattern{ roomSize * 0.2f, 0.6f,  0.5f },
        EarlyPattern{ roomSize * 0.3f, 0.5f, -0.4f },
        EarlyPattern{ roomSize * 0.4f, 0.4f,  0.3f },
        EarlyPattern{ roomSize * 0.5f, 0.3f, -0.2f },
        EarlyPattern{ roomSize * 0.6f, 0.25f, 0.15f },
        EarlyPattern{ roomSize * 0.7f, 0.2f, -0.1f },
        EarlyPattern{ roomSize * 0.8f, 0.15f, 0.05f }
    };
    
    for (size_t i = 0; i < earlyReflections.size(); ++i) {
        earlyReflections[i].prepare(pattern[i].delayMs, sampleRate, maxDelaySamples);
        earlyReflections[i].gain = pattern[i].gain;
        earlyReflections[i].pan = pattern[i].pan;
    }
}

void RoomEngine::updateParameters()
{
    // Map diffusion to feedback gain (0.5-0.85)
    feedbackGain = 0.5f + (params.diffusion / 100.0f) * 0.35f;
    feedbackGain = juce::jlimit(0.5f, 0.85f, feedbackGain);
    
    // Update room size based on timeScale
    roomSizeMs = 20.0f * params.timeScale;
    initializeEarlyReflections(sampleRate, roomSizeMs);
}

void RoomEngine::processEarlyReflections(juce::AudioBuffer<float>& buffer, float gain)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();
    
    for (int sample = 0; sample < numSamples; ++sample) {
        for (int ch = 0; ch < numChannels; ++ch) {
            float* channelData = buffer.getWritePointer(ch);
            float input = channelData[sample];
            
            float earlySum = 0.0f;
            
            // Process each early reflection
            for (auto& early : earlyReflections) {
                float reflection = early.read();
                
                // Apply panning (simple stereo spread)
                float panFactor = 1.0f;
                if (numChannels == 2) {
                    if (ch == 0) {  // Left channel
                        panFactor = early.pan < 0.0f ? (1.0f + early.pan) : 1.0f;
                    } else {  // Right channel
                        panFactor = early.pan > 0.0f ? (1.0f - early.pan) : 1.0f;
                    }
                }
                
                earlySum += reflection * early.gain * panFactor;
                early.write(input);
            }
            
            // Mix early reflections
            channelData[sample] = input + earlySum * gain;
        }
    }
}

void RoomEngine::processLateReverb(juce::AudioBuffer<float>& buffer, float gain)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();
    
    // Calculate modulation
    const float modIncrement = 2.0f * juce::MathConstants<float>::pi * params.modRateHz / static_cast<float>(sampleRate);
    float modAmount = params.modDepth * 0.0001f;
    
    for (int sample = 0; sample < numSamples; ++sample) {
        // Calculate modulation
        float mod = 1.0f;
        if (params.modDepth > 0.01f) {
            mod = 1.0f + std::sin(modPhase) * modAmount;
            modPhase += modIncrement;
            if (modPhase > 2.0f * juce::MathConstants<float>::pi) {
                modPhase -= 2.0f * juce::MathConstants<float>::pi;
            }
        }
        
        for (int ch = 0; ch < numChannels; ++ch) {
            float* channelData = buffer.getWritePointer(ch);
            float input = channelData[sample];
            
            // Read from all late delays
            std::array<float, numLateLines> delayed;
            for (size_t i = 0; i < lateDelays.size(); ++i) {
                int delaySamples = static_cast<int>(baseLateDelays[i] * params.timeScale * mod);
                delaySamples = juce::jlimit(1, static_cast<int>(lateDelays[i].buffer.size()) - 1, delaySamples);
                delayed[i] = lateDelays[i].read(delaySamples);
            }
            
            // Mix through matrix
            std::array<float, numLateLines> mixed;
            for (int i = 0; i < numLateLines; ++i) {
                mixed[i] = 0.0f;
                for (int j = 0; j < numLateLines; ++j) {
                    mixed[i] += mixingMatrix[i][j] * delayed[j];
                }
            }
            
            // Sum output
            float output = 0.0f;
            for (int i = 0; i < numLateLines; ++i) {
                output += mixed[i];
            }
            
            // Write feedback
            for (size_t i = 0; i < lateDelays.size(); ++i) {
                lateDelays[i].write(input + mixed[i] * feedbackGain);
            }
            
            // Mix late reverb
            channelData[sample] += output * gain;
        }
    }
}

void RoomEngine::process(juce::AudioBuffer<float>& buffer)
{
    // Depth parameter: 0 = all early, 1 = all late
    const float depth = params.depth / 100.0f;
    const float earlyGain = (1.0f - depth) * 0.8f;  // Scale down early
    const float lateGain = depth * 0.7f;  // Scale down late
    
    // Process early reflections
    processEarlyReflections(buffer, earlyGain);
    
    // Process late reverb
    processLateReverb(buffer, lateGain);
}
