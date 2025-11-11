#include "PluginEditor.h"

// PresetBrowser implementation
PresetBrowser::PresetBrowser(AmbiGlassConvoVerbAudioProcessor& p)
: processor(p)
{
    presetList.setModel(this);
    presetList.setRowHeight(20);
    addAndMakeVisible(presetList);
    refreshList();
}

int PresetBrowser::getNumRows()
{
    return presets.size();
}

void PresetBrowser::paintListBoxItem(int rowNumber, juce::Graphics& g, int width, int height, bool rowIsSelected)
{
    if (rowNumber >= 0 && rowNumber < presets.size()) {
        if (rowIsSelected) {
            g.fillAll(juce::Colour(0xff66ccff).withAlpha(0.3f));
        }
        g.setColour(juce::Colours::white);
        g.setFont(14.0f);
        g.drawText(presets[rowNumber].getFileNameWithoutExtension(), 4, 0, width - 4, height, juce::Justification::left);
    }
}

void PresetBrowser::listBoxItemClicked(int row, const juce::MouseEvent&)
{
    if (row >= 0 && row < presets.size()) {
        processor.loadPreset(presets[row]);
    }
}

void PresetBrowser::refreshList()
{
    presets = PresetManager::getPresetFiles();
    presetList.updateContent();
}

void PresetBrowser::loadSelected()
{
    int selected = presetList.getSelectedRow();
    if (selected >= 0 && selected < presets.size()) {
        processor.loadPreset(presets[selected]);
    }
}

void PresetBrowser::saveCurrent()
{
    juce::FileChooser chooser("Save Preset", PresetManager::getPresetFolder(), "*.ambipreset");
    if (chooser.browseForFileToSave(true)) {
        processor.savePreset(chooser.getResult());
        refreshList();
    }
}

void PresetBrowser::deleteSelected()
{
    int selected = presetList.getSelectedRow();
    if (selected >= 0 && selected < presets.size()) {
        presets[selected].deleteFile();
        refreshList();
    }
}

AmbiGlassConvoVerbAudioProcessorEditor::AmbiGlassConvoVerbAudioProcessorEditor (AmbiGlassConvoVerbAudioProcessor& p)
: juce::AudioProcessorEditor (&p), proc(p), presetBrowser(p)
{
    setLookAndFeel(&lg);
    setResizable(true, true);
    setSize (820, 520);

    modeBox.addItemList (juce::StringArray{ "IR", "Spring", "Plate", "Room", "Hall" }, 1);
    addAndMakeVisible(modeBox);

    auto initKnob = [&](juce::Slider& s) {
        s.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
        s.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 18);
        addAndMakeVisible(s);
    };

    initKnob(timeKnob); initKnob(widthKnob); initKnob(depthKnob);
    initKnob(diffusionKnob); initKnob(modDepthKnob); initKnob(modRateKnob);

    hpSlider.setSliderStyle(juce::Slider::LinearHorizontal);
    lpSlider.setSliderStyle(juce::Slider::LinearHorizontal);
    dryWetSlider.setSliderStyle(juce::Slider::LinearHorizontal);
    addAndMakeVisible(hpSlider); addAndMakeVisible(lpSlider); addAndMakeVisible(dryWetSlider);

    initKnob(eqLo); initKnob(eqMid); initKnob(eqHi);

    // Preset and IR buttons
    loadIRButton.setButtonText("Load IR...");
    loadIRButton.onClick = [this] { loadIRClicked(); };
    addAndMakeVisible(loadIRButton);
    
    loadPresetButton.setButtonText("Load");
    loadPresetButton.onClick = [this] { loadPresetClicked(); };
    addAndMakeVisible(loadPresetButton);
    
    savePresetButton.setButtonText("Save");
    savePresetButton.onClick = [this] { savePresetClicked(); };
    addAndMakeVisible(savePresetButton);
    
    irInfoLabel.setText("No IR loaded", juce::dontSendNotification);
    irInfoLabel.setJustificationType(juce::Justification::left);
    addAndMakeVisible(irInfoLabel);
    
    addAndMakeVisible(presetBrowser);

    aMode = std::make_unique<juce::AudioProcessorValueTreeState::ComboBoxAttachment>(proc.parameters.apvts, "mode", modeBox);
    aTime = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(proc.parameters.apvts, "rtScale", timeKnob);
    aWidth= std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(proc.parameters.apvts, "width", widthKnob);
    aDepth= std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(proc.parameters.apvts, "depth", depthKnob);
    aDiff = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(proc.parameters.apvts, "diffusion", diffusionKnob);
    aModD = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(proc.parameters.apvts, "modDepth", modDepthKnob);
    aModR = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(proc.parameters.apvts, "modRate", modRateKnob);
    aHP   = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(proc.parameters.apvts, "hpHz", hpSlider);
    aLP   = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(proc.parameters.apvts, "lpHz", lpSlider);
    aDW   = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(proc.parameters.apvts, "dryWet", dryWetSlider);
    aEQL  = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(proc.parameters.apvts, "eqLoGain", eqLo);
    aEQM  = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(proc.parameters.apvts, "eqMidGain", eqMid);
    aEQH  = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(proc.parameters.apvts, "eqHiGain", eqHi);
}

void AmbiGlassConvoVerbAudioProcessorEditor::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colours::black.withAlpha (0.9f));
    auto r = getLocalBounds().toFloat();
    juce::Colour glow (0xff66ccff);
    g.setColour (glow.withAlpha(0.1f));
    g.fillRoundedRectangle (r.reduced(6), 16.0f);
    g.setColour (juce::Colours::white);
    g.setFont (18.0f);
    g.drawText ("AmbiGlass ConvoVerb", 12, 8, 280, 24, juce::Justification::left);
}

void AmbiGlassConvoVerbAudioProcessorEditor::resized()
{
    auto area = getLocalBounds().reduced(12);
    auto top = area.removeFromTop(28);
    modeBox.setBounds(top.removeFromLeft(220));

    auto knobRow = area.removeFromTop(160);
    auto w = knobRow.getWidth() / 6;
    timeKnob.setBounds(knobRow.removeFromLeft(w).reduced(8));
    widthKnob.setBounds(knobRow.removeFromLeft(w).reduced(8));
    depthKnob.setBounds(knobRow.removeFromLeft(w).reduced(8));
    diffusionKnob.setBounds(knobRow.removeFromLeft(w).reduced(8));
    modDepthKnob.setBounds(knobRow.removeFromLeft(w).reduced(8));
    modRateKnob.setBounds(knobRow.removeFromLeft(w).reduced(8));

    auto sliders = area.removeFromTop(90);
    hpSlider.setBounds(sliders.removeFromTop(28));
    lpSlider.setBounds(sliders.removeFromTop(28));
    dryWetSlider.setBounds(sliders.removeFromTop(28));

    auto eqRow = area.removeFromTop(100);
    auto ew = eqRow.getWidth()/3;
    eqLo.setBounds(eqRow.removeFromLeft(ew).reduced(8));
    eqMid.setBounds(eqRow.removeFromLeft(ew).reduced(8));
    eqHi.setBounds(eqRow.removeFromLeft(ew).reduced(8));
    
    // Preset browser and IR loader
    auto presetArea = area.removeFromTop(120);
    auto leftCol = presetArea.removeFromLeft(200);
    presetBrowser.setBounds(leftCol.reduced(4));
    
    auto buttonCol = presetArea.removeFromLeft(100);
    loadIRButton.setBounds(buttonCol.removeFromTop(24).reduced(2));
    loadPresetButton.setBounds(buttonCol.removeFromTop(24).reduced(2));
    savePresetButton.setBounds(buttonCol.removeFromTop(24).reduced(2));
    
    irInfoLabel.setBounds(presetArea.reduced(4));
}

void AmbiGlassConvoVerbAudioProcessorEditor::loadIRClicked()
{
    juce::FileChooser chooser("Load Impulse Response", {}, "*.wav;*.aiff;*.flac");
    if (chooser.browseForFileToOpen()) {
        auto file = chooser.getResult();
        if (proc.loadIR(file)) {
            irInfoLabel.setText(file.getFileName(), juce::dontSendNotification);
        } else {
            irInfoLabel.setText("Failed to load IR", juce::dontSendNotification);
        }
    }
}

void AmbiGlassConvoVerbAudioProcessorEditor::loadPresetClicked()
{
    presetBrowser.loadSelected();
}

void AmbiGlassConvoVerbAudioProcessorEditor::savePresetClicked()
{
    presetBrowser.saveCurrent();
}
