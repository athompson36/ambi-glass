#pragma once
#include <JuceHeader.h>

class LiquidGlassLookAndFeel : public juce::LookAndFeel_V4 {
public:
    LiquidGlassLookAndFeel(){
        setColour(juce::Slider::textBoxTextColourId, juce::Colours::white);
        setColour(juce::Slider::thumbColourId, juce::Colour(0xff66ccff));
    }
};
