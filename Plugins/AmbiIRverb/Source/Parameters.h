#pragma once
#include <JuceHeader.h>

struct AdvancedSnapshot
{
    juce::NamedValueSet data;
};

struct Parameters
{
    Parameters(juce::AudioProcessor& proc);

    std::unique_ptr<juce::AudioProcessorValueTreeState::ParameterLayout> createLayout();
    AdvancedSnapshot getAdvancedSnapshot() const { return {}; }

    juce::AudioProcessorValueTreeState apvts;
    juce::AudioParameterFloat* dryWet { nullptr };
    juce::AudioParameterFloat* hpHz { nullptr };
    juce::AudioParameterFloat* lpHz { nullptr };
    juce::AudioParameterFloat* rtScale { nullptr };
    juce::AudioParameterFloat* width { nullptr };
    juce::AudioParameterFloat* depth { nullptr };
    juce::AudioParameterFloat* modDepth { nullptr };
    juce::AudioParameterFloat* modRate { nullptr };
    juce::AudioParameterFloat* diffusion { nullptr };
    juce::AudioParameterFloat* eqLoGain { nullptr };
    juce::AudioParameterFloat* eqMidGain { nullptr };
    juce::AudioParameterFloat* eqHiGain { nullptr };
    juce::AudioParameterChoice* mode { nullptr };
};
