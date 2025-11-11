#pragma once
#include <JuceHeader.h>
#include "HybridVerb.h"

struct PresetData {
    juce::String name;
    ReverbMode mode;
    juce::String irPath;
    juce::NamedValueSet params;
    juce::NamedValueSet advanced;
};

class PresetManager {
public:
    static bool savePreset(const juce::File& file, const PresetData& data);
    static std::unique_ptr<PresetData> loadPreset(const juce::File& file);
    static juce::Array<juce::File> getPresetFiles();
    
    static juce::File getPresetFolder() {
        auto dir = juce::File::getSpecialLocation(juce::File::userDocumentsDirectory)
                    .getChildFile("AmbiGlass/Presets");
        dir.createDirectory();
        return dir;
    }
    
    static juce::File getDefaultPresetFolder() {
        // Also check for presets in the plugin bundle/resources
        return juce::File::getSpecialLocation(juce::File::currentExecutableFile)
                .getParentDirectory().getChildFile("Presets");
    }
};
