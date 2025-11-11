#include "HybridVerb.h"
#include "ConvoEngine.h"
#include "SpringEngine.h"
#include "PlateEngine.h"
#include "RoomEngine.h"
#include "HallEngine.h"

void HybridVerb::prepare(const juce::dsp::ProcessSpec& spec)
{
    ir.reset(new IRConvolutionEngine());
    spring.reset(new SpringEngine());
    plate.reset(new PlateEngine());
    room.reset(new RoomEngine());
    hall.reset(new HallEngine());

    ir->prepare(spec);
    spring->prepare(spec);
    plate->prepare(spec);
    room->prepare(spec);
    hall->prepare(spec);
}

void HybridVerb::process(juce::AudioBuffer<float>& buffer)
{
    switch (mode)
    {
        case ReverbMode::IR:      ir->setParams(params);      ir->process(buffer); break;
        case ReverbMode::Spring:  spring->setParams(params);  spring->process(buffer); break;
        case ReverbMode::Plate:   plate->setParams(params);   plate->process(buffer); break;
        case ReverbMode::Room:    room->setParams(params);    room->process(buffer); break;
        case ReverbMode::Hall:    hall->setParams(params);    hall->process(buffer); break;
    }
}

bool HybridVerb::loadIR(const juce::File& file)
{
    if (auto* convo = dynamic_cast<IRConvolutionEngine*>(ir.get())) {
        return convo->loadIR(file);
    }
    return false;
}

int HybridVerb::getIRLatency() const
{
    if (auto* convo = dynamic_cast<const IRConvolutionEngine*>(ir.get())) {
        return convo->getLatencySamples();
    }
    return 0;
}
