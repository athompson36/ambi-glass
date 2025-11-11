#include "HallEngine.h"
#include <cmath>

HallEngine::HallEngine()
{
    params.timeScale = 1.0f;
    params.diffusion = 0.65f;
    params.width = 1.0f;
    params.modDepth = 0.0f;
    params.modRate = 0.3f;
    
    // Initialize Householder matrix
    initializeHouseholderMatrix();
    
    // Initialize decay times (will be updated in prepare)
    initializeDecayTimes(baseRT60);
}

void HallEngine::prepare(const juce::dsp::ProcessSpec& spec)
{
    sampleRate = spec.sampleRate;
    
    // Calculate max delay needed (longest delay * max timeScale * 2)
    int maxDelaySamples = static_cast<int>(spec.sampleRate * 0.6);  // 600ms max
    int bufferSize = maxDelaySamples * 2;
    
    // Large delays for hall character (100-500ms)
    std::array<int, numLines> delayMs = {
        113, 173, 229, 283, 337, 397, 449, 503,
        563, 613, 673, 727, 787, 839, 887, 947
    };
    
    for (size_t i = 0; i < delays.size(); ++i) {
        baseDelaySamples[i] = static_cast<int>(delayMs[i] * spec.sampleRate / 1000.0);
        delays[i].prepare(baseDelaySamples[i], bufferSize);
    }
    
    // Prepare damping filters
    for (size_t i = 0; i < dampingFilters.size(); ++i) {
        dampingFilters[i].prepare(spec);
        // Higher delay lines get more damping (simulate HF loss)
        float cutoff = 3000.0f + (i / static_cast<float>(numLines)) * 5000.0f;
        dampingCoeffs[i] = juce::dsp::IIR::Coefficients<float>::makeLowPass(
            spec.sampleRate, cutoff, 0.5f);  // Soft Q
        *dampingFilters[i].state = *dampingCoeffs[i];
    }
    
    // Initialize decay times
    initializeDecayTimes(baseRT60);
    
    reset();
    updateParameters();
}

void HallEngine::reset()
{
    for (auto& delay : delays) {
        std::fill(delay.buffer.begin(), delay.buffer.end(), 0.0f);
        delay.writePos = 0;
    }
    
    modPhase = 0.0f;
}

void HallEngine::initializeHouseholderMatrix()
{
    // Householder matrix for 16x16: H[i][j] = (i==j ? 1-2/N : -2/N)
    const float N = static_cast<float>(numLines);
    const float scale = 2.0f / N;
    
    for (int i = 0; i < numLines; ++i) {
        for (int j = 0; j < numLines; ++j) {
            if (i == j) {
                mixingMatrix[i][j] = 1.0f - scale;
            } else {
                mixingMatrix[i][j] = -scale;
            }
        }
    }
}

void HallEngine::initializeDecayTimes(float baseRT60)
{
    // LF-weighted decay: lower frequencies decay slower
    // Higher delay lines (higher indices) = higher frequencies = faster decay
    for (int i = 0; i < numLines; ++i) {
        // Simulate frequency-dependent decay
        // Lower indices (LF) have longer decay, higher indices (HF) have shorter decay
        float freqFactor = 1.0f + (i / static_cast<float>(numLines)) * 0.5f;
        float rt60 = baseRT60 / freqFactor;
        
        // Convert RT60 to decay gain per sample
        // RT60 = -60dB decay, so gain = 10^(-60/(20*RT60*sampleRate))
        float samplesPerRT60 = rt60 * sampleRate;
        decayGains[i] = std::pow(10.0f, -60.0f / (20.0f * samplesPerRT60));
        decayGains[i] = juce::jlimit(0.5f, 0.99f, decayGains[i]);
        
        delays[i].decayGain = decayGains[i];
    }
}

void HallEngine::updateParameters()
{
    // Map diffusion to feedback gain (0.6-0.9)
    feedbackGain = 0.6f + (params.diffusion / 100.0f) * 0.3f;
    feedbackGain = juce::jlimit(0.6f, 0.9f, feedbackGain);
    
    // Update RT60 based on timeScale
    float scaledRT60 = baseRT60 * params.timeScale;
    initializeDecayTimes(scaledRT60);
    
    // Update damping based on diffusion (higher diffusion = more damping)
    float dampingAmount = params.diffusion / 100.0f;
    for (size_t i = 0; i < dampingFilters.size(); ++i) {
        float baseCutoff = 3000.0f + (i / static_cast<float>(numLines)) * 5000.0f;
        float cutoff = baseCutoff * (1.0f - dampingAmount * 0.4f);  // Reduce with more diffusion
        cutoff = juce::jlimit(500.0f, 20000.0f, cutoff);
        
        dampingCoeffs[i] = juce::dsp::IIR::Coefficients<float>::makeLowPass(
            sampleRate, cutoff, 0.5f);  // Soft Q
        *dampingFilters[i].state = *dampingCoeffs[i];
    }
}

void HallEngine::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();
    
    // Calculate modulation
    const float modIncrement = 2.0f * juce::MathConstants<float>::pi * params.modRateHz / static_cast<float>(sampleRate);
    float modAmount = params.modDepth * 0.0001f;
    
    for (int sample = 0; sample < numSamples; ++sample) {
        // Calculate modulation for delay lengths
        float mod = 1.0f;
        if (params.modDepth > 0.01f) {
            mod = 1.0f + std::sin(modPhase) * modAmount;
            modPhase += modIncrement;
            if (modPhase > 2.0f * juce::MathConstants<float>::pi) {
                modPhase -= 2.0f * juce::MathConstants<float>::pi;
            }
        }
        
        // Process each channel
        for (int ch = 0; ch < numChannels; ++ch) {
            float* channelData = buffer.getWritePointer(ch);
            float input = channelData[sample];
            
            // Calculate scaled delay lengths
            std::array<float, numLines> delayed;
            for (size_t i = 0; i < delays.size(); ++i) {
                int delaySamples = static_cast<int>(baseDelaySamples[i] * params.timeScale * mod);
                delaySamples = juce::jlimit(1, static_cast<int>(delays[i].buffer.size()) - 1, delaySamples);
                delayed[i] = delays[i].read(delaySamples);
            }
            
            // Apply damping filters (soft HF damping)
            for (size_t i = 0; i < dampingFilters.size(); ++i) {
                delayed[i] = dampingFilters[i].processSample(delayed[i]);
            }
            
            // Apply LF-weighted decay
            for (size_t i = 0; i < delays.size(); ++i) {
                delayed[i] *= delays[i].decayGain;
            }
            
            // Mix through Householder matrix
            std::array<float, numLines> mixed;
            for (int i = 0; i < numLines; ++i) {
                mixed[i] = 0.0f;
                for (int j = 0; j < numLines; ++j) {
                    mixed[i] += mixingMatrix[i][j] * delayed[j];
                }
            }
            
            // Calculate output (sum of mixed signals)
            float output = 0.0f;
            for (int i = 0; i < numLines; ++i) {
                output += mixed[i];
            }
            
            // Write feedback with per-line decay
            for (size_t i = 0; i < delays.size(); ++i) {
                delays[i].write(input + mixed[i] * feedbackGain * delays[i].decayGain);
            }
            
            // Mix dry/wet (hall character: mostly wet, long tail)
            const float dryGain = 0.05f;
            const float wetGain = 0.95f;
            
            channelData[sample] = input * dryGain + output * wetGain;
        }
    }
}
