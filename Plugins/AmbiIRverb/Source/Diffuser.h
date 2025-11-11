#pragma once
#include <JuceHeader.h>

class Diffuser {
public:
    void prepare(const juce::dsp::ProcessSpec& spec) { sampleRate = spec.sampleRate; juce::ignoreUnused(spec); }
    void setAmount(float a) { amount = juce::jlimit(0.0f, 1.0f, a/100.0f); }
    void process(juce::AudioBuffer<float>& buf) {
        if (amount <= 1e-6f) return;
        auto n = buf.getNumSamples();
        for (int ch=0; ch<buf.getNumChannels(); ++ch) {
            auto* x = buf.getWritePointer(ch);
            float g = 0.35f * amount;
            for (int i=1; i<n; ++i) {
                auto y = x[i] + g * x[i-1];
                x[i-1] = x[i-1] - g * y;
                x[i] = y;
            }
        }
    }
private:
    double sampleRate = 48000.0;
    float amount = 0.0f;
};
