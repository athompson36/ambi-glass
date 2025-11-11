#include "SpringEngine.h"

SpringEngine::SpringEngine()
{
    // Initialize with default parameters
    params.timeScale = 1.0f;
    params.diffusion = 0.35f;
    params.width = 1.0f;
    params.modDepth = 0.0f;
    params.modRate = 0.3f;
}

void SpringEngine::prepare(const juce::dsp::ProcessSpec& spec)
{
    sampleRate = spec.sampleRate;
    
    // Calculate max delay needed
    int maxDelaySamples = static_cast<int>(spec.sampleRate * 0.6);  // 600ms max
    
    // Prepare allpass stages
    for (size_t i = 0; i < apStages.size(); ++i) {
        apStages[i].prepare(maxDelaySamples, apDelaysMs[i], spec.sampleRate);
    }
    
    // Prepare delay tanks
    for (size_t i = 0; i < tanks.size(); ++i) {
        tanks[i].prepare(tankDelaysMs[i], spec.sampleRate);
    }
    
    reset();
    updateParameters();
}

void SpringEngine::reset()
{
    for (auto& stage : apStages) {
        std::fill(stage.delayLine.begin(), stage.delayLine.end(), 0.0f);
        stage.writePos = 0;
    }
    
    for (auto& tank : tanks) {
        std::fill(tank.delayLine.begin(), tank.delayLine.end(), 0.0f);
        tank.writePos = 0;
        tank.lastSample = 0.0f;
    }
    
    modPhase = 0.0f;
}

void SpringEngine::updateParameters()
{
    // Map diffusion (0-100%) to AP feedback (0.3-0.7)
    float apFeedback = 0.3f + (params.diffusion / 100.0f) * 0.4f;
    for (auto& stage : apStages) {
        stage.setFeedback(apFeedback);
    }
    
    // Map width to tank delay difference for stereo spread
    float widthFactor = params.width;
    
    // Drip effect: use modDepth as drip amount (0-50% max)
    dripAmount = juce::jlimit(0.0f, 0.5f, params.modDepth / 200.0f);
}

float SpringEngine::applyDrip(float input, float amount)
{
    if (amount < 0.01f) return input;
    
    // Nonlinearity: soft saturation + slight distortion
    float saturated = std::tanh(input * (1.0f + amount * 2.0f));
    return input * (1.0f - amount) + saturated * amount;
}

void SpringEngine::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();
    
    // Update modulation phase
    const float modIncrement = 2.0f * juce::MathConstants<float>::pi * params.modRateHz / static_cast<float>(sampleRate);
    
    for (int sample = 0; sample < numSamples; ++sample) {
        // Calculate modulation (subtle delay length variation)
        float mod = 1.0f;
        if (params.modDepth > 0.01f) {
            mod = 1.0f + std::sin(modPhase) * params.modDepth * 0.0001f;  // Very subtle
            modPhase += modIncrement;
            if (modPhase > 2.0f * juce::MathConstants<float>::pi) {
                modPhase -= 2.0f * juce::MathConstants<float>::pi;
            }
        }
        
        // Process each channel
        for (int ch = 0; ch < numChannels; ++ch) {
            float* channelData = buffer.getWritePointer(ch);
            float input = channelData[sample];
            
            // Apply drip effect (nonlinearity)
            input = applyDrip(input, dripAmount);
            
            // Pass through dispersive allpass ladder
            float apOutput = input;
            for (auto& stage : apStages) {
                apOutput = stage.process(apOutput);
            }
            
            // Split into delay tanks (use different tanks per channel for stereo)
            int tankIdx = ch % numTanks;
            
            // Apply time scaling with optional modulation
            float effectiveTimeScale = params.timeScale * mod;
            
            // Process through delay tank
            float tankOutput = tanks[tankIdx].process(apOutput, effectiveTimeScale, 0.3f);
            
            // Mix: 30% dry, 70% wet (spring character)
            const float dryGain = 0.3f;
            const float wetGain = 0.7f;
            
            channelData[sample] = input * dryGain + tankOutput * wetGain;
        }
    }
}
