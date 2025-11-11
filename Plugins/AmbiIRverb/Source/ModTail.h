#pragma once
#include <JuceHeader.h>

class ModTail {
public:
    void prepare(const juce::dsp::ProcessSpec& spec){ sr = spec.sampleRate; }
    void setRate(float hz){ rate = hz; }
    void setDepth(float d){ depth = d; }
    void process(juce::AudioBuffer<float>& buf){
        if (depth <= 0.0001f) return;
        const int n = buf.getNumSamples();
        const float modAmp = depth * 0.0005f;
        for (int ch=0; ch<buf.getNumChannels(); ++ch){
            auto* x = buf.getWritePointer(ch);
            for (int i=0; i<n; ++i){
                float ph = 2.0f * juce::MathConstants<float>::pi * (phase + i / sr * rate + ch*0.13f);
                x[i] = x[i] + modAmp * std::sin(ph) * x[i];
            }
        }
        phase += n / sr * rate;
        phase -= std::floor(phase);
    }
private:
    double sr = 48000.0;
    float rate = 0.3f, depth = 0.0f;
    float phase = 0.0f;
};
