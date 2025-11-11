#pragma once
#include <JuceHeader.h>

class MsWidth {
public:
    void prepare(const juce::dsp::ProcessSpec&){}
    void setWidth(float w){ width = w; }
    void process(juce::AudioBuffer<float>& buf){
        auto n = buf.getNumSamples();
        if (buf.getNumChannels() < 2) return;
        auto* L = buf.getWritePointer(0);
        auto* R = buf.getWritePointer(1);
        for (int i=0;i<n;++i){
            float M = 0.5f*(L[i]+R[i]);
            float S = 0.5f*(L[i]-R[i]) * width;
            L[i] = M + S;
            R[i] = M - S;
        }
    }
private:
    float width = 1.0f; // 0..2
};
