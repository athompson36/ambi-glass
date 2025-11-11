cmake_minimum_required(VERSION 3.22)
project(AmbiGlassConvoVerb VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# JUCE: use local subdir if present, else FetchContent
if(EXISTS ${CMAKE_SOURCE_DIR}/JUCE/CMakeLists.txt)
    message(STATUS "Using local JUCE subdirectory")
    add_subdirectory(JUCE)
else()
    include(FetchContent)
    FetchContent_Declare(
        juce
        GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
        GIT_TAG 8.0.0
    )
    FetchContent_MakeAvailable(juce)
endif()

juce_add_plugin(AmbiGlassConvoVerb
    COMPANY_NAME "Flyover Studios"
    BUNDLE_ID com.flyoverstudios.ambiglassconvoverb
    PLUGIN_NAME "AmbiGlass ConvoVerb"
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT FALSE
    NEEDS_MIDI_OUTPUT FALSE
    MICROPHONE_PERMISSION_ENABLED FALSE
    FORMATS VST3 AU
    PRODUCT_NAME "AmbiGlass ConvoVerb"
    COPY_PLUGIN_AFTER_BUILD TRUE)

target_sources(AmbiGlassConvoVerb PRIVATE
    Source/PluginProcessor.cpp
    Source/PluginEditor.cpp
    Source/Parameters.cpp
    Source/ConvoEngine.cpp
    Source/Diffuser.cpp
    Source/ModTail.cpp
    Source/MsWidth.cpp
    Source/OutputEQ.cpp
    Source/FileIO.cpp
    Source/LookAndFeel.cpp
    Source/HybridVerb.cpp
    Source/SpringEngine.cpp
    Source/PlateEngine.cpp
    Source/RoomEngine.cpp
    Source/HallEngine.cpp
)

target_compile_definitions(AmbiGlassConvoVerb
    PRIVATE
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0)

target_link_libraries(AmbiGlassConvoVerb PRIVATE
    juce::juce_audio_utils
    juce::juce_dsp
    juce::juce_gui_extra
    juce::juce_recommended_warning_flags
    juce::juce_recommended_config_flags
    juce::juce_recommended_lto_flags)
