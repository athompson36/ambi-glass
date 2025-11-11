#include "Parameters.h"
using APVTS = juce::AudioProcessorValueTreeState;

static juce::NormalisableRange<float> percentRange() { return {0.0f, 100.0f}; }

Parameters::Parameters(juce::AudioProcessor& proc)
: apvts(proc, nullptr, "PARAMS", *createLayout())
{
    dryWet   = dynamic_cast<juce::AudioParameterFloat*>(apvts.getParameter("dryWet"));
    hpHz     = dynamic_cast<juce::AudioParameterFloat*>(apvts.getParameter("hpHz"));
    lpHz     = dynamic_cast<juce::AudioParameterFloat*>(apvts.getParameter("lpHz"));
    rtScale  = dynamic_cast<juce::AudioParameterFloat*>(apvts.getParameter("rtScale"));
    width    = dynamic_cast<juce::AudioParameterFloat*>(apvts.getParameter("width"));
    depth    = dynamic_cast<juce::AudioParameterFloat*>(apvts.getParameter("depth"));
    modDepth = dynamic_cast<juce::AudioParameterFloat*>(apvts.getParameter("modDepth"));
    modRate  = dynamic_cast<juce::AudioParameterFloat*>(apvts.getParameter("modRate"));
    diffusion= dynamic_cast<juce::AudioParameterFloat*>(apvts.getParameter("diffusion"));
    eqLoGain = dynamic_cast<juce::AudioParameterFloat*>(apvts.getParameter("eqLoGain"));
    eqMidGain= dynamic_cast<juce::AudioParameterFloat*>(apvts.getParameter("eqMidGain"));
    eqHiGain = dynamic_cast<juce::AudioParameterFloat*>(apvts.getParameter("eqHiGain"));
    mode     = dynamic_cast<juce::AudioParameterChoice*>(apvts.getParameter("mode"));
}

std::unique_ptr<APVTS::ParameterLayout> Parameters::createLayout()
{
    std::vector<std::unique_ptr<juce::RangedAudioParameter>> p;

    p.push_back (std::make_unique<juce::AudioParameterFloat>("dryWet", "Dry/Wet", percentRange(), 30.0f));
    p.push_back (std::make_unique<juce::AudioParameterFloat>("hpHz", "High-Pass Hz", juce::NormalisableRange<float>(10.f, 2000.f, 0.f, 0.3f), 30.f));
    p.push_back (std::make_unique<juce::AudioParameterFloat>("lpHz", "Low-Pass Hz",  juce::NormalisableRange<float>(2000.f, 22050.f, 0.f, 0.3f), 18000.f));

    p.push_back (std::make_unique<juce::AudioParameterFloat>("rtScale", "Reverb Time (x)", juce::NormalisableRange<float>(0.5f, 2.0f), 1.0f));
    p.push_back (std::make_unique<juce::AudioParameterFloat>("width", "Width", juce::NormalisableRange<float>(0.0f, 2.0f), 1.0f));
    p.push_back (std::make_unique<juce::AudioParameterFloat>("depth", "Depth", percentRange(), 50.0f));
    p.push_back (std::make_unique<juce::AudioParameterFloat>("diffusion", "Diffusion", percentRange(), 35.0f));
    p.push_back (std::make_unique<juce::AudioParameterFloat>("modDepth", "Mod Depth", percentRange(), 10.0f));
    p.push_back (std::make_unique<juce::AudioParameterFloat>("modRate",  "Mod Rate Hz", juce::NormalisableRange<float>(0.01f, 3.0f, 0.0f, 0.3f), 0.3f));

    p.push_back (std::make_unique<juce::AudioParameterFloat>("eqLoGain", "EQ Low Gain dB", juce::NormalisableRange<float>(-12.f, 12.f), 0.f));
    p.push_back (std::make_unique<juce::AudioParameterFloat>("eqMidGain","EQ Mid Gain dB", juce::NormalisableRange<float>(-12.f, 12.f), 0.f));
    p.push_back (std::make_unique<juce::AudioParameterFloat>("eqHiGain", "EQ High Gain dB", juce::NormalisableRange<float>(-12.f, 12.f), 0.f));

    p.push_back (std::make_unique<juce::AudioParameterChoice>("mode", "Mode", juce::StringArray{ "IR","Spring","Plate","Room","Hall" }, 0));

    return std::make_unique<APVTS::ParameterLayout>(p.begin(), p.end());
}
