#include "ConvoEngine.h"

IRConvolutionEngine::IRConvolutionEngine()
{
    params.timeScale = 1.0f;
    currentTimeScale = 1.0f;
    irInfo = "No IR loaded";
}

void IRConvolutionEngine::prepare(const juce::dsp::ProcessSpec& spec)
{
    this->spec = spec;
    
    conv.prepare(spec);
    convLL.prepare(spec);
    convLR.prepare(spec);
    convRL.prepare(spec);
    convRR.prepare(spec);
}

void IRConvolutionEngine::reset()
{
    conv.reset();
    convLL.reset();
    convLR.reset();
    convRL.reset();
    convRR.reset();
}

IRFormat IRConvolutionEngine::detectIRFormat(juce::AudioFormatReader* reader)
{
    if (reader == nullptr) return IRFormat::Stereo;
    
    int numChannels = reader->numChannels;
    if (numChannels == 1) return IRFormat::Mono;
    if (numChannels == 2) return IRFormat::Stereo;
    if (numChannels >= 4) return IRFormat::TrueStereo;
    
    return IRFormat::Stereo;  // Default
}

void IRConvolutionEngine::loadTrueStereoIR(juce::AudioFormatReader* reader)
{
    if (reader == nullptr) return;
    
    // Read all 4 channels
    int numSamples = static_cast<int>(reader->lengthInSamples);
    juce::AudioBuffer<float> buffer(4, numSamples);
    reader->read(&buffer, 0, numSamples, 0, true, true);
    
    // Extract individual channels
    juce::AudioBuffer<float> ll(1, numSamples);
    juce::AudioBuffer<float> lr(1, numSamples);
    juce::AudioBuffer<float> rl(1, numSamples);
    juce::AudioBuffer<float> rr(1, numSamples);
    
    ll.copyFrom(0, 0, buffer, 0, 0, numSamples);
    lr.copyFrom(0, 0, buffer, 1, 0, numSamples);
    rl.copyFrom(0, 0, buffer, 2, 0, numSamples);
    rr.copyFrom(0, 0, buffer, 3, 0, numSamples);
    
    // Load into convolvers
    convLL.loadImpulseResponse(ll, spec.sampleRate, juce::dsp::Convolution::Stereo::no, juce::dsp::Convolution::Trim::yes, 0);
    convLR.loadImpulseResponse(lr, spec.sampleRate, juce::dsp::Convolution::Stereo::no, juce::dsp::Convolution::Trim::yes, 0);
    convRL.loadImpulseResponse(rl, spec.sampleRate, juce::dsp::Convolution::Stereo::no, juce::dsp::Convolution::Trim::yes, 0);
    convRR.loadImpulseResponse(rr, spec.sampleRate, juce::dsp::Convolution::Stereo::no, juce::dsp::Convolution::Trim::yes, 0);
}

bool IRConvolutionEngine::loadIR(const juce::File& file)
{
    if (!file.existsAsFile()) {
        irInfo = "File not found";
        return false;
    }
    
    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();
    
    std::unique_ptr<juce::AudioFormatReader> reader(formatManager.createReaderFor(file));
    if (reader == nullptr) {
        irInfo = "Unsupported format";
        return false;
    }
    
    format = detectIRFormat(reader.get());
    irSampleRate = reader->sampleRate;
    
    if (format == IRFormat::TrueStereo) {
        // Load 4-channel true-stereo IR
        loadTrueStereoIR(reader.get());
        trueStereoMode = true;
        
        irInfo = juce::String(reader->numChannels) + "ch True-Stereo, " +
                 juce::String(static_cast<int>(reader->sampleRate)) + "Hz, " +
                 juce::String(reader->lengthInSamples / reader->sampleRate, 2) + "s";
    } else {
        // Load mono or stereo IR
        if (format == IRFormat::Mono) {
            conv.loadImpulseResponse(file, spec.sampleRate, juce::dsp::Convolution::Stereo::no, juce::dsp::Convolution::Trim::yes, 0);
            irInfo = "Mono, " + juce::String(static_cast<int>(reader->sampleRate)) + "Hz, " +
                     juce::String(reader->lengthInSamples / reader->sampleRate, 2) + "s";
        } else {
            conv.loadImpulseResponse(file, spec.sampleRate, juce::dsp::Convolution::Stereo::yes, juce::dsp::Convolution::Trim::yes, 0);
            irInfo = "Stereo, " + juce::String(static_cast<int>(reader->sampleRate)) + "Hz, " +
                     juce::String(reader->lengthInSamples / reader->sampleRate, 2) + "s";
        }
        trueStereoMode = false;
    }
    
    // Store original IR for time scaling (if needed)
    // Note: Time scaling via resampling is complex, so we'll use a simpler approach
    // For now, timeScale parameter affects the IR length by truncation/extension
    
    return true;
}

void IRConvolutionEngine::updateTimeScale()
{
    // Time scaling for convolution is complex - would require resampling the IR
    // For now, we'll note that the parameter is available but full implementation
    // would require storing and resampling the IR buffer
    // This is a placeholder for future enhancement
    currentTimeScale = params.timeScale;
}

void IRConvolutionEngine::process(juce::AudioBuffer<float>& buffer)
{
    if (trueStereoMode && buffer.getNumChannels() >= 2) {
        // True-stereo: 4 convolvers (LL, LR, RL, RR)
        // Left output = LL*L + LR*R
        // Right output = RL*L + RR*R
        const int numSamples = buffer.getNumSamples();
        
        // Extract left and right input
        juce::AudioBuffer<float> leftInput(1, numSamples);
        juce::AudioBuffer<float> rightInput(1, numSamples);
        leftInput.copyFrom(0, 0, buffer, 0, 0, numSamples);
        rightInput.copyFrom(0, 0, buffer, 1, 0, numSamples);
        
        // Process: LL*L
        juce::AudioBuffer<float> llOut(1, numSamples);
        llOut.copyFrom(0, 0, leftInput, 0, 0, numSamples);
        juce::dsp::AudioBlock<float> llBlock(llOut);
        juce::dsp::ProcessContextReplacing<float> llCtx(llBlock);
        convLL.process(llCtx);
        
        // Process: LR*R
        juce::AudioBuffer<float> lrOut(1, numSamples);
        lrOut.copyFrom(0, 0, rightInput, 0, 0, numSamples);
        juce::dsp::AudioBlock<float> lrBlock(lrOut);
        juce::dsp::ProcessContextReplacing<float> lrCtx(lrBlock);
        convLR.process(lrCtx);
        
        // Process: RL*L
        juce::AudioBuffer<float> rlOut(1, numSamples);
        rlOut.copyFrom(0, 0, leftInput, 0, 0, numSamples);
        juce::dsp::AudioBlock<float> rlBlock(rlOut);
        juce::dsp::ProcessContextReplacing<float> rlCtx(rlBlock);
        convRL.process(rlCtx);
        
        // Process: RR*R
        juce::AudioBuffer<float> rrOut(1, numSamples);
        rrOut.copyFrom(0, 0, rightInput, 0, 0, numSamples);
        juce::dsp::AudioBlock<float> rrBlock(rrOut);
        juce::dsp::ProcessContextReplacing<float> rrCtx(rrBlock);
        convRR.process(rrCtx);
        
        // Mix outputs: Left = LL + LR, Right = RL + RR
        buffer.copyFrom(0, 0, llOut, 0, 0, numSamples);
        buffer.addFrom(0, 0, lrOut, 0, 0, numSamples);
        buffer.copyFrom(1, 0, rlOut, 0, 0, numSamples);
        buffer.addFrom(1, 0, rrOut, 0, 0, numSamples);
    } else {
        // Standard stereo or mono
        juce::dsp::AudioBlock<float> block(buffer);
        juce::dsp::ProcessContextReplacing<float> ctx(block);
        conv.process(ctx);
    }
    
    // Apply width parameter (M/S processing)
    if (params.width != 1.0f && buffer.getNumChannels() >= 2) {
        const int numSamples = buffer.getNumSamples();
        auto* L = buffer.getWritePointer(0);
        auto* R = buffer.getWritePointer(1);
        
        for (int i = 0; i < numSamples; ++i) {
            float M = 0.5f * (L[i] + R[i]);
            float S = 0.5f * (L[i] - R[i]) * params.width;
            L[i] = M + S;
            R[i] = M - S;
        }
    }
}

int IRConvolutionEngine::getLatencySamples() const
{
    if (trueStereoMode) {
        return convLL.getLatency();
    }
    return conv.getLatency();
}
