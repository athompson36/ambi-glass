#pragma once
#include <JuceHeader.h>
#include "Parameters.h"
#include "HybridVerb.h"
#include "OutputEQ.h"
#include "MsWidth.h"
#include "Diffuser.h"
#include "ModTail.h"
#include "FileIO.h"
#include "LookAndFeel.h"

class AmbiGlassConvoVerbAudioProcessor : public juce::AudioProcessor
{
public:
    AmbiGlassConvoVerbAudioProcessor();
    ~AmbiGlassConvoVerbAudioProcessor() override = default;

    void prepareToPlay (double sampleRate, int samplesPerBlock) override;
    void releaseResources() override {}
   #ifndef JucePlugin_PreferredChannelConfigurations
    bool isBusesLayoutSupported (const BusesLayout& layouts) const override;
   #endif
    void processBlock (juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override { return true; }

    const juce::String getName() const override { return JucePlugin_Name; }
    bool acceptsMidi() const override { return false; }
    bool producesMidi() const override { return false; }
    bool isMidiEffect() const override { return false; }
    double getTailLengthSeconds() const override { return 10.0; }

    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram (int) override {}
    const juce::String getProgramName (int) override { return {}; }
    void changeProgramName (int, const juce::String&) override {}

    void getStateInformation (juce::MemoryBlock& destData) override;
    void setStateInformation (const void* data, int sizeInBytes) override;

    // Preset management
    bool loadPreset(const juce::File& file);
    bool savePreset(const juce::File& file);
    bool loadIR(const juce::File& file);
    juce::String getIRInfo() const;

    Parameters parameters;
private:
    juce::dsp::IIR::Filter<float> hpFilter, lpFilter;
    Diffuser diffuser;
    HybridVerb hybrid;
    ModTail modTail;
    OutputEQ outputEQ;
    MsWidth msWidth;
    juce::AudioBuffer<float> dryBuffer;
    LiquidGlassLookAndFeel lookAndFeel;
    
    juce::String currentIRPath;  // Store current IR path for preset saving

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (AmbiGlassConvoVerbAudioProcessor)
};
