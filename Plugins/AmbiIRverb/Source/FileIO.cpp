#include "FileIO.h"

bool PresetManager::savePreset(const juce::File& file, const PresetData& data)
{
    juce::var root;
    root["version"] = "1.0.0";
    root["name"] = data.name;
    
    // Mode
    const char* modeNames[] = { "IR", "Spring", "Plate", "Room", "Hall" };
    root["mode"] = modeNames[static_cast<int>(data.mode)];
    
    // IR path (if applicable)
    if (data.mode == ReverbMode::IR && data.irPath.isNotEmpty()) {
        root["irPath"] = data.irPath;
    }
    
    // Parameters
    juce::var params;
    if (data.params.size() > 0) {
        for (int i = 0; i < data.params.size(); ++i) {
            auto name = data.params.getName(i);
            auto value = data.params[name];
            params[name] = value;
        }
    }
    root["params"] = params;
    
    // Advanced (if present)
    if (data.advanced.size() > 0) {
        juce::var advanced;
        for (int i = 0; i < data.advanced.size(); ++i) {
            auto name = data.advanced.getName(i);
            auto value = data.advanced[name];
            advanced[name] = value;
        }
        root["advanced"] = advanced;
    }
    
    // Write to file
    juce::FileOutputStream stream(file);
    if (stream.openedOk()) {
        juce::JSON::writeToStream(stream, root);
        return true;
    }
    return false;
}

std::unique_ptr<PresetData> PresetManager::loadPreset(const juce::File& file)
{
    if (!file.existsAsFile()) return nullptr;
    
    juce::var root = juce::JSON::parse(file);
    if (!root.isObject()) return nullptr;
    
    auto data = std::make_unique<PresetData>();
    
    // Name
    data->name = root.getProperty("name", file.getFileNameWithoutExtension()).toString();
    
    // Mode
    juce::String modeStr = root.getProperty("mode", "IR").toString();
    if (modeStr == "Spring") data->mode = ReverbMode::Spring;
    else if (modeStr == "Plate") data->mode = ReverbMode::Plate;
    else if (modeStr == "Room") data->mode = ReverbMode::Room;
    else if (modeStr == "Hall") data->mode = ReverbMode::Hall;
    else data->mode = ReverbMode::IR;
    
    // IR path
    data->irPath = root.getProperty("irPath", "").toString();
    
    // Parameters
    juce::var params = root.getProperty("params", juce::var());
    if (params.isObject()) {
        auto* obj = params.getDynamicObject();
        if (obj != nullptr) {
            auto props = obj->getProperties();
            for (auto& prop : props) {
                float value = 0.0f;
                if (prop.value.isDouble()) {
                    value = static_cast<float>(prop.value);
                } else if (prop.value.isInt()) {
                    value = static_cast<float>(static_cast<int>(prop.value));
                }
                data->params.set(prop.name.toString(), value);
            }
        }
    }
    
    // Advanced
    juce::var advanced = root.getProperty("advanced", juce::var());
    if (advanced.isObject()) {
        auto* obj = advanced.getDynamicObject();
        if (obj != nullptr) {
            auto props = obj->getProperties();
            for (auto& prop : props) {
                data->advanced.set(prop.name.toString(), prop.value);
            }
        }
    }
    
    return data;
}

juce::Array<juce::File> PresetManager::getPresetFiles()
{
    juce::Array<juce::File> files;
    
    // Check user preset folder
    auto userFolder = getPresetFolder();
    if (userFolder.exists()) {
        userFolder.findChildFiles(files, juce::File::findFiles, false, "*.ambipreset");
    }
    
    // Check default preset folder (bundle)
    auto defaultFolder = getDefaultPresetFolder();
    if (defaultFolder.exists()) {
        juce::Array<juce::File> defaultFiles;
        defaultFolder.findChildFiles(defaultFiles, juce::File::findFiles, false, "*.ambipreset");
        files.addArray(defaultFiles);
    }
    
    // Sort by name
    files.sort();
    
    return files;
}
