#pragma once
#include <JuceHeader.h>

class OutputEQ {
public:
    void prepare(const juce::dsp::ProcessSpec& spec){
        chain.prepare(spec);
        fs = spec.sampleRate;
        update();
    }
    void setGains(float lo, float mid, float hi){
        loGain = lo; midGain = mid; hiGain = hi; update();
    }
    void process(juce::AudioBuffer<float>& buf){
        juce::dsp::AudioBlock<float> block(buf);
        juce::dsp::ProcessContextReplacing<float> ctx(block);
        chain.process(ctx);
    }
private:
    void update(){
        auto& lo = chain.get<0>(); auto& mid = chain.get<1>(); auto& hi = chain.get<2>();
        *lo.state = *juce::dsp::IIR::Coefficients<float>::makeLowShelf (fs, 120.0f, 0.707f, juce::Decibels::decibelsToGain(loGain));
        *mid.state= *juce::dsp::IIR::Coefficients<float>::makePeakFilter(fs, 2000.0f, 0.8f, juce::Decibels::decibelsToGain(midGain));
        *hi.state = *juce::dsp::IIR::Coefficients<float>::makeHighShelf(fs, 8000.0f, 0.707f, juce::Decibels::decibelsToGain(hiGain));
    }
    double fs = 48000.0;
    float loGain=0, midGain=0, hiGain=0;
    juce::dsp::ProcessorChain<
        juce::dsp::IIR::Filter<float>,
        juce::dsp::IIR::Filter<float>,
        juce::dsp::IIR::Filter<float>> chain;
};
