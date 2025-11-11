#pragma once
#include <JuceHeader.h>
#include "PluginProcessor.h"
#include "LookAndFeel.h"
#include "FileIO.h"

class PresetBrowser : public juce::Component, public juce::ListBoxModel
{
public:
    PresetBrowser(AmbiGlassConvoVerbAudioProcessor& p);
    
    int getNumRows() override;
    void paintListBoxItem(int rowNumber, juce::Graphics& g, int width, int height, bool rowIsSelected) override;
    void listBoxItemClicked(int row, const juce::MouseEvent&) override;
    
    void refreshList();
    void loadSelected();
    void saveCurrent();
    void deleteSelected();
    
private:
    AmbiGlassConvoVerbAudioProcessor& processor;
    juce::ListBox presetList;
    juce::Array<juce::File> presets;
};

class AmbiGlassConvoVerbAudioProcessorEditor : public juce::AudioProcessorEditor
{
public:
    AmbiGlassConvoVerbAudioProcessorEditor (AmbiGlassConvoVerbAudioProcessor&);
    ~AmbiGlassConvoVerbAudioProcessorEditor() override = default;
    void paint (juce::Graphics&) override;
    void resized() override;

private:
    AmbiGlassConvoVerbAudioProcessor& proc;

    juce::ComboBox modeBox;
    juce::Slider timeKnob, widthKnob, depthKnob, diffusionKnob, modDepthKnob, modRateKnob;
    juce::Slider hpSlider, lpSlider, dryWetSlider;
    juce::Slider eqLo, eqMid, eqHi;

    std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> aTime, aWidth, aDepth, aDiff, aModD, aModR, aHP, aLP, aDW, aEQL, aEQM, aEQH;
    std::unique_ptr<juce::AudioProcessorValueTreeState::ComboBoxAttachment> aMode;

    // Preset and IR management
    PresetBrowser presetBrowser;
    juce::TextButton loadIRButton;
    juce::TextButton loadPresetButton;
    juce::TextButton savePresetButton;
    juce::Label irInfoLabel;

    LiquidGlassLookAndFeel lg;

    void loadIRClicked();
    void loadPresetClicked();
    void savePresetClicked();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (AmbiGlassConvoVerbAudioProcessorEditor)
};
