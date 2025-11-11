#include "PluginProcessor.h"
#include "PluginEditor.h"
#include "FileIO.h"

AmbiGlassConvoVerbAudioProcessor::AmbiGlassConvoVerbAudioProcessor()
: AudioProcessor (BusesProperties()
    .withInput  ("Input",  juce::AudioChannelSet::stereo(), true)
    .withOutput ("Output", juce::AudioChannelSet::stereo(), true))
, parameters(*this)
{}

bool AmbiGlassConvoVerbAudioProcessor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
    return layouts.getMainInputChannelSet() == juce::AudioChannelSet::stereo()
        && layouts.getMainOutputChannelSet() == juce::AudioChannelSet::stereo();
}

void AmbiGlassConvoVerbAudioProcessor::prepareToPlay (double sr, int blockSize)
{
    juce::dsp::ProcessSpec spec { sr, (juce::uint32) blockSize, 2 };

    hpFilter.reset(); lpFilter.reset();
    *hpFilter.state = *juce::dsp::IIR::Coefficients<float>::makeHighPass (sr, parameters.hpHz->get());
    *lpFilter.state = *juce::dsp::IIR::Coefficients<float>::makeLowPass  (sr, parameters.lpHz->get());

    diffuser.prepare(spec);
    hybrid.prepare(spec);
    modTail.prepare(spec);
    outputEQ.prepare(spec);
    msWidth.prepare(spec);

    dryBuffer.setSize(2, blockSize);
}

void AmbiGlassConvoVerbAudioProcessor::processBlock (juce::AudioBuffer<float>& buffer, juce::MidiBuffer&)
{
    juce::ScopedNoDenormals _noDenormals;
    const auto numSamples = buffer.getNumSamples();

    dryBuffer.makeCopyOf(buffer);

    juce::dsp::AudioBlock<float> block (buffer);
    juce::dsp::ProcessContextReplacing<float> ctx (block);

    *hpFilter.state = *juce::dsp::IIR::Coefficients<float>::makeHighPass (getSampleRate(), parameters.hpHz->get());
    *lpFilter.state = *juce::dsp::IIR::Coefficients<float>::makeLowPass  (getSampleRate(), parameters.lpHz->get());

    hpFilter.process(ctx);
    lpFilter.process(ctx);

    diffuser.setAmount(parameters.diffusion->get());
    diffuser.process(buffer);

    EngineParams p;
    p.timeScale   = parameters.rtScale->get();
    p.width       = parameters.width->get();
    p.depth       = parameters.depth->get();
    p.modDepth    = parameters.modDepth->get();
    p.modRateHz   = parameters.modRate->get();
    hybrid.setMode((ReverbMode) parameters.mode->getIndex());
    hybrid.setParams(p);
    hybrid.process(buffer);

    modTail.setRate(parameters.modRate->get());
    modTail.setDepth(parameters.modDepth->get());
    modTail.process(buffer);

    outputEQ.setGains(parameters.eqLoGain->get(), parameters.eqMidGain->get(), parameters.eqHiGain->get());
    outputEQ.process(buffer);

    msWidth.setWidth(parameters.width->get());
    msWidth.process(buffer);

    const float mix = parameters.dryWet->get() * 0.01f;
    buffer.applyGain (mix);
    dryBuffer.applyGain (std::sqrt (1.0f - (mix * mix)));
    for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        buffer.addFrom (ch, 0, dryBuffer, ch, 0, numSamples);
}

void AmbiGlassConvoVerbAudioProcessor::getStateInformation (juce::MemoryBlock& destData)
{
    auto state = parameters.apvts.copyState();
    juce::MemoryOutputStream mos (destData, false);
    state.writeToStream (mos);
}

void AmbiGlassConvoVerbAudioProcessor::setStateInformation (const void* data, int sizeInBytes)
{
    auto tree = juce::ValueTree::readFromData (data, (size_t) sizeInBytes);
    if (tree.isValid())
        parameters.apvts.replaceState (tree);
}

bool AmbiGlassConvoVerbAudioProcessor::loadPreset(const juce::File& file)
{
    auto data = PresetManager::loadPreset(file);
    if (data == nullptr) return false;
    
    // Set mode
    if (parameters.mode != nullptr) {
        int modeIndex = static_cast<int>(data->mode);
        parameters.mode->setValueNotifyingHost(parameters.mode->convertTo0to1(modeIndex));
    }
    
    // Set parameters from preset
    for (int i = 0; i < data->params.size(); ++i) {
        auto name = data->params.getName(i);
        auto* param = parameters.apvts.getParameter(name);
        if (param != nullptr) {
            float denormalizedValue = static_cast<float>(data->params[name]);
            // Convert from actual parameter value to normalized 0-1
            float normalizedValue = param->convertTo0to1(denormalizedValue);
            param->setValueNotifyingHost(normalizedValue);
        }
    }
    
    // Load IR if needed
    if (data->mode == ReverbMode::IR && data->irPath.isNotEmpty()) {
        juce::File irFile(data->irPath);
        if (irFile.existsAsFile()) {
            loadIR(irFile);
        }
    }
    
    return true;
}

bool AmbiGlassConvoVerbAudioProcessor::savePreset(const juce::File& file)
{
    PresetData data;
    data.name = file.getFileNameWithoutExtension();
    
    if (parameters.mode != nullptr) {
        data.mode = static_cast<ReverbMode>(parameters.mode->getIndex());
    } else {
        data.mode = ReverbMode::IR;
    }
    
    // Copy all parameters
    for (auto* param : parameters.apvts.getParameters()) {
        if (param != nullptr) {
            float value = param->getValue();
            // Convert from 0-1 to actual parameter value
            float denormalizedValue = param->convertFrom0to1(value);
            data.params.set(param->getName(1024), denormalizedValue);
        }
    }
    
    // Save IR path if in IR mode
    if (data.mode == ReverbMode::IR && currentIRPath.isNotEmpty()) {
        data.irPath = currentIRPath;
    }
    
    return PresetManager::savePreset(file, data);
}

bool AmbiGlassConvoVerbAudioProcessor::loadIR(const juce::File& file)
{
    if (hybrid.loadIR(file)) {
        currentIRPath = file.getFullPathName();
        return true;
    }
    return false;
}

juce::String AmbiGlassConvoVerbAudioProcessor::getIRInfo() const
{
    // This would need to be exposed through HybridVerb
    // For now, return empty string
    return "";
}
