#include "PlateEngine.h"

PlateEngine::PlateEngine()
{
    params.timeScale = 1.0f;
    params.diffusion = 0.6f;
    params.width = 1.0f;
    params.modDepth = 0.0f;
    params.modRate = 0.3f;
    
    // Initialize base delay lengths in samples (will be converted in prepare)
    // These are in milliseconds, will be converted based on sample rate
    std::array<int, numLines> delayMs = { 37, 87, 181, 271, 359, 449, 563, 641 };
    
    // Initialize Householder matrix
    initializeHouseholderMatrix();
}

void PlateEngine::prepare(const juce::dsp::ProcessSpec& spec)
{
    sampleRate = spec.sampleRate;
    
    // Calculate max delay needed (longest delay * max timeScale * 2 for safety)
    int maxDelaySamples = static_cast<int>(spec.sampleRate * 0.3);  // 300ms max
    int bufferSize = maxDelaySamples * 2;
    
    // Convert delay times from ms to samples
    std::array<int, numLines> delayMs = { 37, 87, 181, 271, 359, 449, 563, 641 };
    
    for (size_t i = 0; i < delays.size(); ++i) {
        baseDelaySamples[i] = static_cast<int>(delayMs[i] * spec.sampleRate / 1000.0);
        delays[i].prepare(baseDelaySamples[i], bufferSize);
    }
    
    // Prepare damping filters
    for (size_t i = 0; i < dampingFilters.size(); ++i) {
        dampingFilters[i].prepare(spec);
        // Higher delay lines get more damping (simulate HF loss in plate)
        float cutoff = 2000.0f + (i / static_cast<float>(numLines)) * 6000.0f;
        dampingCoeffs[i] = juce::dsp::IIR::Coefficients<float>::makeLowPass(
            spec.sampleRate, cutoff, 0.707f);
        *dampingFilters[i].state = *dampingCoeffs[i];
    }
    
    reset();
    updateParameters();
}

void PlateEngine::reset()
{
    for (auto& delay : delays) {
        std::fill(delay.buffer.begin(), delay.buffer.end(), 0.0f);
        delay.writePos = 0;
    }
    
    modPhase = 0.0f;
}

void PlateEngine::initializeHouseholderMatrix()
{
    // Householder matrix: H = I - 2*v*v^T / (v^T*v)
    // For 8x8: H[i][j] = (i==j ? 1 : 0) - 2/N
    // Simplified: H[i][j] = (i==j ? 1-2/N : -2/N)
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

void PlateEngine::updateParameters()
{
    // Map diffusion (0-100%) to feedback gain (0.5-0.9)
    feedbackGain = 0.5f + (params.diffusion / 100.0f) * 0.4f;
    feedbackGain = juce::jlimit(0.5f, 0.9f, feedbackGain);
    
    // Update damping based on diffusion (higher diffusion = more damping)
    float dampingAmount = params.diffusion / 100.0f;
    for (size_t i = 0; i < dampingFilters.size(); ++i) {
        float baseCutoff = 2000.0f + (i / static_cast<float>(numLines)) * 6000.0f;
        float cutoff = baseCutoff * (1.0f - dampingAmount * 0.5f);  // Reduce with more diffusion
        cutoff = juce::jlimit(500.0f, 20000.0f, cutoff);
        
        dampingCoeffs[i] = juce::dsp::IIR::Coefficients<float>::makeLowPass(
            sampleRate, cutoff, 0.707f);
        *dampingFilters[i].state = *dampingCoeffs[i];
    }
}

void PlateEngine::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();
    
    // Calculate modulation
    const float modIncrement = 2.0f * juce::MathConstants<float>::pi * params.modRateHz / static_cast<float>(sampleRate);
    float modAmount = params.modDepth * 0.0001f;  // Very subtle modulation
    
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
            
            // Apply damping filters (process each sample)
            for (size_t i = 0; i < dampingFilters.size(); ++i) {
                delayed[i] = dampingFilters[i].processSample(delayed[i]);
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
            
            // Write feedback to delays
            for (size_t i = 0; i < delays.size(); ++i) {
                delays[i].write(input + mixed[i] * feedbackGain);
            }
            
            // Mix dry/wet (plate character: mostly wet)
            const float dryGain = 0.1f;
            const float wetGain = 0.9f;
            
            channelData[sample] = input * dryGain + output * wetGain;
        }
    }
}
