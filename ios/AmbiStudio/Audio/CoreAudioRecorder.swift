#if os(macOS)
import Foundation
import AVFoundation
import CoreAudio
import CoreAudioKit
import AudioUnit
import AudioToolbox
import Combine
import Accelerate

/// Core Audio implementation for macOS - provides direct device access and full channel control
final class CoreAudioRecorder: AudioRecorderProtocol {
    // Configuration
    var selectedDeviceID: String = "__no_devices__"
    var selectedInputChannels: [Int] = []
    var requestedSampleRate: Double = 48000.0
    var recordingFormat: RecordingFormat = .ambiA
    
    // State
    @Published private(set) var currentSampleRate: Double = 48000.0
    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var hasMicrophonePermission: Bool = false
    
    // Meters
    private let meterSubject = PassthroughSubject<[CGFloat], Never>()
    var meterPublisher: AnyPublisher<[CGFloat], Never> {
        meterSubject
            .throttle(for: .milliseconds(50), scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }
    
    // Callbacks
    var onBufferReceived: ((AVAudioPCMBuffer) -> Void)?
    
    // Core Audio components
    private var audioUnit: AudioUnit?
    private var inputCallback: AURenderCallbackStruct?
    private var isRecordingActive: Bool = false
    private var monitoringTask: Task<Void, Never>?
    private let audioQueue = DispatchQueue(label: "com.ambi-studio.coreaudio", qos: .userInitiated)
    
    // Cached device info for callback
    private var cachedDeviceID: AudioDeviceID?
    private var cachedDeviceChannelCount: Int = 0
    private var cachedDeviceFormat: AudioStreamBasicDescription?
    private var cachedStreamConfiguration: [Int] = [] // Channels per stream
    
    // Buffer management
    private var meterDecimateCounter: Int = 0
    private let meterDecimateN: Int = 2
    
    init() {
        checkMicrophonePermission()
    }
    
    deinit {
        stop()
        // Can't call async from deinit, so just stop synchronously
        audioQueue.sync {
            if let unit = audioUnit {
                AudioOutputUnitStop(unit)
                AudioUnitUninitialize(unit)
                AudioComponentInstanceDispose(unit)
                audioUnit = nil
            }
        }
    }
    
    // MARK: - Device Management
    
    private func findDevice(byUID uid: String) -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var devicesSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &devicesSize
        )
        
        guard status == noErr else {
            print("❌ CoreAudio: Failed to get devices size: \(status)")
            return nil
        }
        
        let deviceCount = Int(devicesSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &devicesSize,
            &devices
        )
        
        guard status == noErr else {
            print("❌ CoreAudio: Failed to get device list: \(status)")
            return nil
        }
        
        // Find device by UID
        for device in devices {
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            var deviceUID: CFString?
            
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            status = AudioObjectGetPropertyData(
                device,
                &uidAddress,
                0,
                nil,
                &uidSize,
                &deviceUID
            )
            
            if status == noErr, let uidString = deviceUID as String?, uidString == uid {
                return device
            }
        }
        
        return nil
    }
    
    private func getDeviceFormat(deviceID: AudioDeviceID) -> (sampleRate: Double, channelCount: Int, formatID: UInt32)? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: 0
        )
        
        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &size,
            &asbd
        )
        
        guard status == noErr else {
            print("❌ CoreAudio: Failed to get device format: \(status)")
            return nil
        }
        
        print("🔍 CoreAudio: Device format - sampleRate: \(asbd.mSampleRate), channels: \(asbd.mChannelsPerFrame), formatID: \(asbd.mFormatID), bitsPerChannel: \(asbd.mBitsPerChannel), bytesPerFrame: \(asbd.mBytesPerFrame), isInterleaved: \(asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0)")
        
        return (sampleRate: asbd.mSampleRate, channelCount: Int(asbd.mChannelsPerFrame), formatID: asbd.mFormatID)
    }
    
    private func getDeviceStreamConfiguration(deviceID: AudioDeviceID) -> [Int] {
        // Try kAudioObjectPropertyElementMain first, then fall back to kAudioObjectPropertyElementWildcard
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        // If main element fails, try wildcard
        if status != noErr || dataSize == 0 {
            print("⚠️ CoreAudio: Main element failed (status: \(status), size: \(dataSize)), trying wildcard element")
            propertyAddress.mElement = kAudioObjectPropertyElementWildcard
            status = AudioObjectGetPropertyDataSize(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize
            )
        }
        
        guard status == noErr, dataSize > 0 else {
            print("❌ CoreAudio: Failed to get stream configuration size - status: \(status), dataSize: \(dataSize)")
            return []
        }
        
        print("🔍 CoreAudio: Stream config property size: \(dataSize) bytes")
        
        let bufferListPtr = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferListPtr.deallocate() }
        
        status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            bufferListPtr
        )
        
        guard status == noErr else {
            print("❌ CoreAudio: Failed to get stream configuration data - status: \(status)")
            return []
        }
        
        let bufferList = bufferListPtr.assumingMemoryBound(to: AudioBufferList.self)
        let numBuffers = Int(bufferList.pointee.mNumberBuffers)
        
        print("🔍 CoreAudio: AudioBufferList has \(numBuffers) buffers")
        
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        
        var channelsPerStream: [Int] = []
        for (index, buffer) in buffers.enumerated() {
            let channels = Int(buffer.mNumberChannels)
            print("🔍 CoreAudio: Stream \(index): \(channels) channels")
            channelsPerStream.append(channels)
        }
        
        print("✅ CoreAudio: Stream configuration - \(channelsPerStream.count) streams: \(channelsPerStream)")
        return channelsPerStream
    }
    
    private func detectStreamLayoutFromChannelCount(_ channelCount: Int) -> [Int] {
        // Common stream layouts for professional audio interfaces
        // Based on typical device configurations
        print("🔍 CoreAudio: Detecting stream layout for \(channelCount) channels...")
        
        switch channelCount {
        case 1:
            return [1]
        case 2:
            return [2]
        case 4:
            return [4]
        case 8:
            return [8]
        case 16:
            return [8, 8] // Common for 16-channel interfaces
        case 18:
            return [10, 8] // MOTU 828 pattern
        case 24:
            return [12, 12] // Common for 24-channel interfaces
        case 28:
            return [14, 14] // Two 14-channel streams (your device!)
        case 32:
            return [16, 16] // Common for 32-channel interfaces
        case 64:
            return [32, 32] // High-end interfaces
        default:
            // For other counts, try to split evenly if even, or single stream if odd
            if channelCount % 2 == 0 && channelCount > 8 {
                return [channelCount / 2, channelCount / 2]
            } else {
                return [channelCount]
            }
        }
    }
    
    // MARK: - Audio Unit Setup
    
    private func createAudioUnit(deviceID inputDeviceID: AudioDeviceID) throws -> AudioUnit {
        var audioUnit: AudioUnit?
        
        var componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        guard let component = AudioComponentFindNext(nil, &componentDescription) else {
            throw NSError(domain: "CoreAudioRecorder", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to find HAL output component"])
        }
        
        var status = AudioComponentInstanceNew(component, &audioUnit)
        guard status == noErr, let unit = audioUnit else {
            throw NSError(domain: "CoreAudioRecorder", code: Int(status),
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create audio unit instance"])
        }
        
        // Enable input
        var enableIO: UInt32 = 1
        status = AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input,
            1, // Input element
            &enableIO,
            UInt32(MemoryLayout<UInt32>.size)
        )
        guard status == noErr else {
            AudioComponentInstanceDispose(unit)
            throw NSError(domain: "CoreAudioRecorder", code: Int(status),
                         userInfo: [NSLocalizedDescriptionKey: "Failed to enable input"])
        }
        
        // Disable output
        enableIO = 0
        status = AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output,
            0, // Output element
            &enableIO,
            UInt32(MemoryLayout<UInt32>.size)
        )
        guard status == noErr else {
            AudioComponentInstanceDispose(unit)
            throw NSError(domain: "CoreAudioRecorder", code: Int(status),
                         userInfo: [NSLocalizedDescriptionKey: "Failed to disable output"])
        }
        
        // Set device
        var deviceID = inputDeviceID
        status = AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            AudioComponentInstanceDispose(unit)
            throw NSError(domain: "CoreAudioRecorder", code: Int(status),
                         userInfo: [NSLocalizedDescriptionKey: "Failed to set device"])
        }
        
        // Get device format to set on audio unit
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: 0
        )
        
        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        
        status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &size,
            &asbd
        )
        
        guard status == noErr else {
            AudioComponentInstanceDispose(unit)
            throw NSError(domain: "CoreAudioRecorder", code: Int(status),
                         userInfo: [NSLocalizedDescriptionKey: "Failed to get device format for audio unit"])
        }
        
        // Set stream format on input scope
        status = AudioUnitSetProperty(
            unit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            1, // Input element
            &asbd,
            size
        )
        
        guard status == noErr else {
            AudioComponentInstanceDispose(unit)
            throw NSError(domain: "CoreAudioRecorder", code: Int(status),
                         userInfo: [NSLocalizedDescriptionKey: "Failed to set stream format"])
        }
        
        // Verify what format was actually set (audio unit might modify it)
        var actualASBD = AudioStreamBasicDescription()
        var actualSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = AudioUnitGetProperty(
            unit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            1,
            &actualASBD,
            &actualSize
        )
        
        if status == noErr {
            print("🔍 CoreAudio: Audio unit accepted format - channels: \(actualASBD.mChannelsPerFrame), sampleRate: \(actualASBD.mSampleRate), formatID: \(actualASBD.mFormatID), flags: \(actualASBD.mFormatFlags)")
            // Update asbd to match what was actually set
            asbd = actualASBD
        }
        
        // Initialize
        status = AudioUnitInitialize(unit)
        guard status == noErr else {
            AudioComponentInstanceDispose(unit)
            throw NSError(domain: "CoreAudioRecorder", code: Int(status),
                         userInfo: [NSLocalizedDescriptionKey: "Failed to initialize audio unit"])
        }
        
        // After initialization, query what format the AudioUnit is actually using
        var actualInputASBD = AudioStreamBasicDescription()
        var actualInputSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = AudioUnitGetProperty(
            unit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            1,
            &actualInputASBD,
            &actualInputSize
        )
        
        if status == noErr {
            let actualInterleaved = (actualInputASBD.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0
            print("🔍 CoreAudio: AudioUnit actual input format after init:")
            print("   - Channels: \(actualInputASBD.mChannelsPerFrame)")
            print("   - SampleRate: \(actualInputASBD.mSampleRate)")
            print("   - FormatID: \(actualInputASBD.mFormatID)")
            print("   - Flags: \(actualInputASBD.mFormatFlags)")
            print("   - BitsPerChannel: \(actualInputASBD.mBitsPerChannel)")
            print("   - BytesPerFrame: \(actualInputASBD.mBytesPerFrame)")
            print("   - BytesPerPacket: \(actualInputASBD.mBytesPerPacket)")
            print("   - IsInterleaved: \(actualInterleaved)")
        }
        
        return unit
    }
    
    // MARK: - Recording Callback
    
    private func recordingCallback(
        inRefCon: UnsafeMutableRawPointer,
        ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        inTimeStamp: UnsafePointer<AudioTimeStamp>,
        inBusNumber: UInt32,
        inNumberFrames: UInt32,
        ioData: UnsafeMutablePointer<AudioBufferList>?
    ) -> OSStatus {
        let recorder = Unmanaged<CoreAudioRecorder>.fromOpaque(inRefCon).takeUnretainedValue()
        
        guard recorder.isRecordingActive || recorder.isMonitoring else {
            return noErr
        }
        
        // Get the audio unit
        guard let audioUnit = recorder.audioUnit else {
            return noErr
        }
        
        // Query the audio unit's actual input format (not the device format)
        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var status = AudioUnitGetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            1, // Input bus
            &asbd,
            &size
        )
        
        guard status == noErr else {
            print("❌ CoreAudio: Failed to get audio unit input format: \(status)")
            return status
        }
        
        // Debug: Log the format we're getting
        if recorder.meterDecimateCounter < 3 {
            print("🔍 CoreAudio: Audio unit input format - channels: \(asbd.mChannelsPerFrame), sampleRate: \(asbd.mSampleRate), formatID: \(asbd.mFormatID), flags: \(asbd.mFormatFlags)")
            print("   BytesPerFrame: \(asbd.mBytesPerFrame), BytesPerPacket: \(asbd.mBytesPerPacket), BitsPerChannel: \(asbd.mBitsPerChannel)")
        }
        
        // Use the audio unit's format, not the device format
        let audioUnitChannelCount = Int(asbd.mChannelsPerFrame)
        guard audioUnitChannelCount > 0 else {
            print("⚠️ CoreAudio: Audio unit reports 0 channels")
            return noErr
        }
        
        // Use cached stream configuration (queried at setup, not in callback for performance)
        let channelsPerStream = recorder.cachedStreamConfiguration
        
        // Validate we have stream config
        guard !channelsPerStream.isEmpty else {
            if recorder.meterDecimateCounter < 3 {
                print("❌ CoreAudio: No cached stream configuration - this is a setup error")
            }
            return noErr
        }
        
        // Check if format is interleaved - for interleaved, we need buffers per stream (not per channel)
        let isNonInterleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0
        let isInterleaved = !isNonInterleaved
        
        // WORKAROUND: For multi-stream devices, Core Audio HAL often expects non-interleaved
        // even when the ASBD reports interleaved. HOWEVER, the error messages show the AudioUnit
        // explicitly wants 2 buffers (streams). So we should NOT force non-interleaved for this device.
        // Instead, use exactly what the AudioUnit reports via NumberChannelStreams.
        let forceNonInterleaved = false  // Disabled - AudioUnit explicitly wants 2 streams
        let useNonInterleaved = isNonInterleaved || forceNonInterleaved
        
        if recorder.meterDecimateCounter < 3 {
            print("🔍 CoreAudio: Format analysis - isNonInterleaved: \(isNonInterleaved), using: \(useNonInterleaved ? "non-interleaved" : "interleaved")")
        }
        
        let numberOfStreams = channelsPerStream.count
        let sumChannels = channelsPerStream.reduce(0, +)
        
        // Log stream configuration on first few callbacks
        if recorder.meterDecimateCounter < 3 {
            print("🔍 CoreAudio: Using cached streams: \(channelsPerStream), sum: \(sumChannels), audioUnit reports: \(audioUnitChannelCount)")
        }
        
        // Verify cached config matches the audio unit's reported channel count
        guard sumChannels == audioUnitChannelCount else {
            if recorder.meterDecimateCounter < 3 {
                print("❌ CoreAudio: Stream config mismatch - cached sum: \(sumChannels), audioUnit reports: \(audioUnitChannelCount)")
                print("   This means the device stream configuration query failed at setup.")
                print("   Attempting emergency fallback...")
            }
            // Emergency fallback: Try to detect stream layout from format
            // This shouldn't happen if setup worked correctly
            return noErr
        }
        
        // For interleaved formats, we need one buffer per stream (each contains interleaved channels within that stream)
        // For non-interleaved formats, we need one buffer per channel (total audioUnitChannelCount buffers)
        let numberOfBuffers = useNonInterleaved ? audioUnitChannelCount : numberOfStreams
        
        let bytesPerSample = Int(asbd.mBitsPerChannel / 8)
        
        // Debug: Log buffer allocation details
        if recorder.meterDecimateCounter < 3 {
            print("🔍 CoreAudio: Allocating buffers - channels: \(audioUnitChannelCount), useNonInterleaved: \(useNonInterleaved), numBuffers: \(numberOfBuffers), streams: \(channelsPerStream)")
            print("   ASBD: BytesPerFrame=\(asbd.mBytesPerFrame), BytesPerPacket=\(asbd.mBytesPerPacket), Frames=\(inNumberFrames)")
            print("   Expected total data size: \(Int(inNumberFrames) * Int(asbd.mBytesPerFrame)) bytes")
        }
        
        // Allocate buffer list matching the audio unit's expected format
        let bufferListSize = MemoryLayout<AudioBufferList>.offset(of: \AudioBufferList.mBuffers)! + 
                            MemoryLayout<AudioBuffer>.size * numberOfBuffers
        let bufferListPtr = UnsafeMutableRawPointer.allocate(byteCount: bufferListSize, alignment: MemoryLayout<Int>.alignment)
            .assumingMemoryBound(to: AudioBufferList.self)
        bufferListPtr.pointee.mNumberBuffers = UInt32(numberOfBuffers)
        
        // Allocate buffers
        var channelBuffers: [UnsafeMutableRawPointer] = []
        let buffersPtr = UnsafeMutableAudioBufferListPointer(bufferListPtr)
        
        if useNonInterleaved {
            // Non-interleaved: one buffer per channel
            for i in 0..<audioUnitChannelCount {
                let bufferSize = Int(inNumberFrames) * bytesPerSample
                let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: MemoryLayout<Float>.alignment)
                buffersPtr[i].mNumberChannels = 1
                buffersPtr[i].mDataByteSize = UInt32(bufferSize)
                buffersPtr[i].mData = buffer
                channelBuffers.append(buffer)
                
                if recorder.meterDecimateCounter < 3 && i < 4 {
                    print("🔍 CoreAudio: Buffer[\(i)] (non-interleaved) - channels: 1, size: \(bufferSize) bytes")
                }
            }
        } else {
            // Interleaved: one buffer per stream with its channels interleaved
            for i in 0..<numberOfStreams {
                let channelsInStream = max(1, channelsPerStream[i])
                let bufferSize = Int(inNumberFrames) * bytesPerSample * channelsInStream
                let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: MemoryLayout<Float>.alignment)
                buffersPtr[i].mNumberChannels = UInt32(channelsInStream)
                buffersPtr[i].mDataByteSize = UInt32(bufferSize)
                buffersPtr[i].mData = buffer
                channelBuffers.append(buffer)
                
                if recorder.meterDecimateCounter < 3 {
                    print("🔍 CoreAudio: Buffer[\(i)] (interleaved) - channels: \(channelsInStream), size: \(bufferSize) bytes (\(inNumberFrames) frames * \(bytesPerSample) bytes * \(channelsInStream) ch)")
                }
            }
        }
        
        // Render audio from device
        status = AudioUnitRender(
            audioUnit,
            ioActionFlags,
            inTimeStamp,
            inBusNumber,
            inNumberFrames,
            bufferListPtr
        )
        
        guard status == noErr else {
            // Clean up
            for buffer in channelBuffers {
                buffer.deallocate()
            }
            bufferListPtr.deallocate()
            print("❌ CoreAudio: AudioUnitRender failed: \(status)")
            return status
        }
        
        // Debug: Log first few samples to verify we're getting data
        if recorder.meterDecimateCounter < 3 {
            let firstBuffer = buffersPtr[0]
            if let firstData = firstBuffer.mData?.assumingMemoryBound(to: Float.self) {
                print("🔍 CoreAudio: First buffer - frames: \(inNumberFrames), audioUnitChannels: \(audioUnitChannelCount), isInterleaved: \(isInterleaved), numBuffers: \(numberOfBuffers), sample[0]: \(firstData[0]), sample[100]: \(firstData[min(100, Int(inNumberFrames)-1)])")
            }
        }
        
        // Get device format for conversion (we still need this for format conversion)
        guard let deviceFormat = recorder.cachedDeviceFormat else {
            // Clean up
            for buffer in channelBuffers {
                buffer.deallocate()
            }
            bufferListPtr.deallocate()
            return noErr
        }
        
        let deviceChannelCount = recorder.cachedDeviceChannelCount
        
        // Extract selected channels and convert to AVAudioPCMBuffer
        // For monitoring, always use first 4 channels; for recording, use recordingFormat.channelCount
        let channelCount = recorder.isMonitoring ? 4 : recorder.recordingFormat.channelCount
        let selectedChannels = Array(recorder.selectedInputChannels.prefix(channelCount))
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: recorder.currentSampleRate,
            channels: AVAudioChannelCount(selectedChannels.count),
            interleaved: false
        ),
        let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: inNumberFrames) else {
            // Clean up
            for buffer in channelBuffers {
                buffer.deallocate()
            }
            bufferListPtr.deallocate()
            return noErr
        }
        
        pcmBuffer.frameLength = inNumberFrames
        
        // Convert and copy selected channels
        // Note: The audio unit might provide fewer channels than the device has
        // We need to map from audio unit channels to device channels
        for (outCh, inCh) in selectedChannels.enumerated() {
            // Map from device channel to audio unit channel
            // For now, assume 1:1 mapping if audio unit has enough channels
            let audioUnitCh = min(inCh, audioUnitChannelCount - 1)
            guard audioUnitCh < audioUnitChannelCount,
                  let channelData = pcmBuffer.floatChannelData?[outCh] else { continue }
            
            // Determine stream index and channel offset within that stream (for interleaved)
            var streamIndex = 0
            var channelOffsetInStream = audioUnitCh
            if !useNonInterleaved {
                var cumulative = 0
                for (idx, chInStream) in channelsPerStream.enumerated() {
                    if audioUnitCh < cumulative + chInStream {
                        streamIndex = idx
                        channelOffsetInStream = audioUnitCh - cumulative
                        break
                    }
                    cumulative += chInStream
                }
            }
            
            // Select source buffer depending on interleaving
            let sourceBuffer: AudioBuffer = useNonInterleaved ? buffersPtr[audioUnitCh] : buffersPtr[streamIndex]
            
            // Convert based on audio unit format (not device format)
            if asbd.mFormatID == kAudioFormatLinearPCM {
                if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
                    // Float format (typically Float32)
                    if let sourceData = sourceBuffer.mData?.assumingMemoryBound(to: Float.self) {
                        if useNonInterleaved {
                            // Non-interleaved: direct copy
                            channelData.update(from: sourceData, count: Int(inNumberFrames))
                        } else {
                            let channelsInThisStream = max(1, channelsPerStream[streamIndex])
                            // Deinterleave this channel
                            let totalFrames = Int(inNumberFrames)
                            for f in 0..<totalFrames {
                                channelData[f] = sourceData[f * channelsInThisStream + channelOffsetInStream]
                            }
                        }
                    }
                } else {
                    // Integer format - need to convert to normalized float [-1.0, 1.0]
                    let _ = (asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger) != 0
                    let _ = (asbd.mFormatFlags & kAudioFormatFlagIsBigEndian) != 0
                    
                    if bytesPerSample == 2 {
                        // Int16
                        if let sourceData = sourceBuffer.mData?.assumingMemoryBound(to: Int16.self) {
                            if useNonInterleaved {
                                var scale: Float = 1.0 / Float(Int16.max)
                                vDSP_vflt16(sourceData, 1, channelData, 1, vDSP_Length(inNumberFrames))
                                vDSP_vsmul(channelData, 1, &scale, channelData, 1, vDSP_Length(inNumberFrames))
                            } else {
                                let channelsInThisStream = max(1, channelsPerStream[streamIndex])
                                let totalFrames = Int(inNumberFrames)
                                var scale: Float = 1.0 / Float(Int16.max)
                                for f in 0..<totalFrames {
                                    channelData[f] = Float(sourceData[f * channelsInThisStream + channelOffsetInStream]) * scale
                                }
                            }
                        }
                    } else if bytesPerSample == 4 {
                        // Int32
                        if let sourceData = sourceBuffer.mData?.assumingMemoryBound(to: Int32.self) {
                            if useNonInterleaved {
                                var scale: Float = 1.0 / Float(Int32.max)
                                vDSP_vflt32(sourceData, 1, channelData, 1, vDSP_Length(inNumberFrames))
                                vDSP_vsmul(channelData, 1, &scale, channelData, 1, vDSP_Length(inNumberFrames))
                            } else {
                                let channelsInThisStream = max(1, channelsPerStream[streamIndex])
                                let totalFrames = Int(inNumberFrames)
                                var scale: Float = 1.0 / Float(Int32.max)
                                for f in 0..<totalFrames {
                                    channelData[f] = Float(sourceData[f * channelsInThisStream + channelOffsetInStream]) * scale
                                }
                            }
                        }
                    } else if bytesPerSample == 1 {
                        // Int8
                        if let sourceData = sourceBuffer.mData?.assumingMemoryBound(to: Int8.self) {
                            if useNonInterleaved {
                                var scale: Float = 1.0 / Float(Int8.max)
                                for i in 0..<Int(inNumberFrames) {
                                    channelData[i] = Float(sourceData[i]) * scale
                                }
                            } else {
                                let channelsInThisStream = max(1, channelsPerStream[streamIndex])
                                let totalFrames = Int(inNumberFrames)
                                var scale: Float = 1.0 / Float(Int8.max)
                                for f in 0..<totalFrames {
                                    channelData[f] = Float(sourceData[f * channelsInThisStream + channelOffsetInStream]) * scale
                                }
                            }
                        }
                    }
                }
            } else {
                // Unknown format - log warning
                if recorder.meterDecimateCounter < 3 {
                    print("⚠️ CoreAudio: Unknown format ID: \(asbd.mFormatID)")
                }
            }
            
            // Debug: Log sample values for first few callbacks
            if recorder.meterDecimateCounter < 3 && outCh == 0 {
                let sample0 = channelData[0]
                let sampleMid = channelData[min(100, Int(inNumberFrames)-1)]
                print("🔍 CoreAudio: Channel \(outCh) (input ch\(inCh)) - sample[0]: \(String(format: "%.6f", sample0)), sample[100]: \(String(format: "%.6f", sampleMid))")
            }
        }
        
        // Clean up
        for buffer in channelBuffers {
            buffer.deallocate()
        }
        bufferListPtr.deallocate()
        
        // Process buffer
        recorder.processBuffer(pcmBuffer)
        
        return noErr
    }
    
    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        // Update meters
        pushMeters(from: buffer)
        
        // Call callback if recording
        if isRecordingActive {
            onBufferReceived?(buffer)
        }
    }
    
    private func pushMeters(from buf: AVAudioPCMBuffer) {
        meterDecimateCounter &+= 1
        if meterDecimateCounter % meterDecimateN != 0 { return }
        
        let n = Int(buf.frameLength)
        var peaks: [CGFloat] = []
        let channelCount = Int(buf.format.channelCount)
        
        for ch in 0..<4 {
            let actualCh = min(ch, channelCount - 1)
            guard let ptr = buf.floatChannelData?[actualCh] else {
                peaks.append(0)
                continue
            }
            var maxVal: Float = 0
            vDSP_maxmgv(ptr, 1, &maxVal, vDSP_Length(n))
            peaks.append(CGFloat(min(1.0, maxVal)))
        }
        
        meterSubject.send(peaks)
    }
    
    // MARK: - AudioRecorderProtocol
    
    func startMonitoring(sampleRate: Double? = nil, bufferFrames: AVAudioFrameCount = 16384) async {
        await stopMonitoring()
        
        guard !selectedDeviceID.isEmpty, selectedDeviceID != "__no_devices__" else {
            print("⚠️ CoreAudio: No device selected")
            return
        }
        
        guard selectedInputChannels.count >= 4 else {
            print("⚠️ CoreAudio: Need at least 4 channels selected")
            return
        }
        
        await audioQueue.sync {
            do {
                // Find device
                guard let deviceID = findDevice(byUID: selectedDeviceID) else {
                    print("❌ CoreAudio: Device not found: \(selectedDeviceID)")
                    return
                }
                
                // Get device format
                guard let (sampleRate, channelCount, formatID) = getDeviceFormat(deviceID: deviceID) else {
                    print("❌ CoreAudio: Failed to get device format")
                    return
                }
                
                // Get full format for callback
                var propertyAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyStreamFormat,
                    mScope: kAudioObjectPropertyScopeInput,
                    mElement: 0
                )
                var asbd = AudioStreamBasicDescription()
                var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
                let formatStatus = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &size, &asbd)
                guard formatStatus == noErr else {
                    print("❌ CoreAudio: Failed to get full device format")
                    return
                }
                
                // Cache device info for callback
                self.cachedDeviceID = deviceID
                self.cachedDeviceChannelCount = channelCount
                self.cachedDeviceFormat = asbd
                
                // Cache stream configuration for callback
                print("🔍 CoreAudio: Querying stream configuration for device \(deviceID)...")
                let deviceStreams = getDeviceStreamConfiguration(deviceID: deviceID)
                
                // Check if we got a valid multi-stream configuration
                if !deviceStreams.isEmpty && deviceStreams.count > 1 {
                    // Device query succeeded with multiple streams - use it
                    self.cachedStreamConfiguration = deviceStreams
                    print("✅ CoreAudio: Using device-reported configuration: \(self.cachedStreamConfiguration)")
                } else {
                    // Device query failed or returned single stream - use pattern detection
                    if !deviceStreams.isEmpty {
                        print("⚠️ CoreAudio: Device reported single stream \(deviceStreams), but we need multi-stream for \(channelCount) channels")
                    } else {
                        print("⚠️ CoreAudio: Device stream config query failed completely")
                    }
                    print("🔍 CoreAudio: Using pattern detection for \(channelCount) channels...")
                    self.cachedStreamConfiguration = detectStreamLayoutFromChannelCount(channelCount)
                    print("✅ CoreAudio: Using detected layout: \(self.cachedStreamConfiguration)")
                }
                
                // Validate channels
                let maxChannel = selectedInputChannels.max() ?? 0
                guard maxChannel < channelCount else {
                    print("❌ CoreAudio: Selected channels out of range (device has \(channelCount) channels)")
                    return
                }
                
                // Create audio unit
                let unit = try createAudioUnit(deviceID: deviceID)
                
                // Set up render callback
                var callbackStruct = AURenderCallbackStruct(
                    inputProc: { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
                        let recorder = Unmanaged<CoreAudioRecorder>.fromOpaque(inRefCon).takeUnretainedValue()
                        return recorder.recordingCallback(
                            inRefCon: inRefCon,
                            ioActionFlags: ioActionFlags,
                            inTimeStamp: inTimeStamp,
                            inBusNumber: inBusNumber,
                            inNumberFrames: inNumberFrames,
                            ioData: ioData
                        )
                    },
                    inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
                )
                
                var callbackStatus = AudioUnitSetProperty(
                    unit,
                    kAudioOutputUnitProperty_SetInputCallback,
                    kAudioUnitScope_Global,
                    0,
                    &callbackStruct,
                    UInt32(MemoryLayout<AURenderCallbackStruct>.size)
                )
                
                guard callbackStatus == noErr else {
                    AudioUnitUninitialize(unit)
                    AudioComponentInstanceDispose(unit)
                    throw NSError(domain: "CoreAudioRecorder", code: Int(callbackStatus),
                                 userInfo: [NSLocalizedDescriptionKey: "Failed to set render callback"])
                }
                
                // Start
                let startStatus = AudioOutputUnitStart(unit)
                guard startStatus == noErr else {
                    AudioUnitUninitialize(unit)
                    AudioComponentInstanceDispose(unit)
                    throw NSError(domain: "CoreAudioRecorder", code: Int(startStatus),
                                 userInfo: [NSLocalizedDescriptionKey: "Failed to start audio unit"])
                }
                
                self.audioUnit = unit
                DispatchQueue.main.async { [weak self] in
                    self?.currentSampleRate = sampleRate
                    self?.isMonitoring = true
                }
                
                print("✅ CoreAudio: Monitoring started - device: \(selectedDeviceID), sampleRate: \(sampleRate)Hz, channels: \(selectedInputChannels.prefix(4))")
            } catch {
                print("❌ CoreAudio: Failed to start monitoring: \(error)")
            }
        }
    }
    
    func stopMonitoring() async {
        await audioQueue.sync {
            if let unit = audioUnit {
                AudioOutputUnitStop(unit)
                AudioUnitUninitialize(unit)
                AudioComponentInstanceDispose(unit)
                audioUnit = nil
            }
            cachedDeviceID = nil
            cachedDeviceChannelCount = 0
            cachedDeviceFormat = nil
            cachedStreamConfiguration = []
            DispatchQueue.main.async { [weak self] in
                self?.isMonitoring = false
            }
        }
    }
    
    func start(sampleRate: Double, bufferFrames: AVAudioFrameCount) async throws {
        await stopMonitoring()
        
        guard !selectedDeviceID.isEmpty, selectedDeviceID != "__no_devices__" else {
            throw NSError(domain: "CoreAudioRecorder", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "No device selected"])
        }
        
        let requiredChannels = recordingFormat.channelCount
        guard selectedInputChannels.count >= requiredChannels else {
            throw NSError(domain: "CoreAudioRecorder", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Must select at least \(requiredChannels) channels"])
        }
        
        try await audioQueue.sync {
            // Find device
            guard let deviceID = findDevice(byUID: selectedDeviceID) else {
                throw NSError(domain: "CoreAudioRecorder", code: -3,
                             userInfo: [NSLocalizedDescriptionKey: "Device not found: \(selectedDeviceID)"])
            }
            
            // Get device format
            guard let (deviceSampleRate, channelCount, formatID) = getDeviceFormat(deviceID: deviceID) else {
                throw NSError(domain: "CoreAudioRecorder", code: -4,
                             userInfo: [NSLocalizedDescriptionKey: "Failed to get device format"])
            }
            
            // Get full format for callback
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamFormat,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: 0
            )
            var asbd = AudioStreamBasicDescription()
            var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            let formatStatus = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &size, &asbd)
            guard formatStatus == noErr else {
                throw NSError(domain: "CoreAudioRecorder", code: -4,
                             userInfo: [NSLocalizedDescriptionKey: "Failed to get full device format"])
            }
            
            // Cache device info for callback
            self.cachedDeviceID = deviceID
            self.cachedDeviceChannelCount = channelCount
            self.cachedDeviceFormat = asbd
            
            // Cache stream configuration for callback
            print("🔍 CoreAudio: Querying stream configuration for device \(deviceID)...")
            let deviceStreams = getDeviceStreamConfiguration(deviceID: deviceID)
            
            // Check if we got a valid multi-stream configuration
            if !deviceStreams.isEmpty && deviceStreams.count > 1 {
                // Device query succeeded with multiple streams - use it
                self.cachedStreamConfiguration = deviceStreams
                print("✅ CoreAudio: Using device-reported configuration: \(self.cachedStreamConfiguration)")
            } else {
                // Device query failed or returned single stream - use pattern detection
                if !deviceStreams.isEmpty {
                    print("⚠️ CoreAudio: Device reported single stream \(deviceStreams), but we need multi-stream for \(channelCount) channels")
                } else {
                    print("⚠️ CoreAudio: Device stream config query failed completely")
                }
                print("🔍 CoreAudio: Using pattern detection for \(channelCount) channels...")
                self.cachedStreamConfiguration = detectStreamLayoutFromChannelCount(channelCount)
                print("✅ CoreAudio: Using detected layout: \(self.cachedStreamConfiguration)")
            }
            
            // Validate channels
            let maxChannel = selectedInputChannels.max() ?? 0
            guard maxChannel < channelCount else {
                throw NSError(domain: "CoreAudioRecorder", code: -5,
                             userInfo: [NSLocalizedDescriptionKey: "Selected channels out of range"])
            }
            
            // Create audio unit
            let unit = try createAudioUnit(deviceID: deviceID)
            
            // Set up render callback
            var callbackStruct = AURenderCallbackStruct(
                inputProc: { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
                    let recorder = Unmanaged<CoreAudioRecorder>.fromOpaque(inRefCon).takeUnretainedValue()
                    return recorder.recordingCallback(
                        inRefCon: inRefCon,
                        ioActionFlags: ioActionFlags,
                        inTimeStamp: inTimeStamp,
                        inBusNumber: inBusNumber,
                        inNumberFrames: inNumberFrames,
                        ioData: ioData
                    )
                },
                inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
            )
            
            var callbackStatus = AudioUnitSetProperty(
                unit,
                kAudioOutputUnitProperty_SetInputCallback,
                kAudioUnitScope_Global,
                0,
                &callbackStruct,
                UInt32(MemoryLayout<AURenderCallbackStruct>.size)
            )
            
            guard callbackStatus == noErr else {
                AudioUnitUninitialize(unit)
                AudioComponentInstanceDispose(unit)
                throw NSError(domain: "CoreAudioRecorder", code: Int(callbackStatus),
                             userInfo: [NSLocalizedDescriptionKey: "Failed to set render callback"])
            }
            
            // Start
            let startStatus = AudioOutputUnitStart(unit)
            guard startStatus == noErr else {
                AudioUnitUninitialize(unit)
                AudioComponentInstanceDispose(unit)
                throw NSError(domain: "CoreAudioRecorder", code: Int(startStatus),
                             userInfo: [NSLocalizedDescriptionKey: "Failed to start audio unit"])
            }
            
            self.audioUnit = unit
            DispatchQueue.main.async { [weak self] in
                self?.currentSampleRate = deviceSampleRate
            }
            self.isRecordingActive = true
            
            print("✅ CoreAudio: Recording started - device: \(selectedDeviceID), sampleRate: \(deviceSampleRate)Hz")
        }
    }
    
    func stop() {
        audioQueue.sync {
            if let unit = audioUnit {
                AudioOutputUnitStop(unit)
                AudioUnitUninitialize(unit)
                AudioComponentInstanceDispose(unit)
                audioUnit = nil
            }
            cachedDeviceID = nil
            cachedDeviceChannelCount = 0
            cachedDeviceFormat = nil
            cachedStreamConfiguration = []
            isRecordingActive = false
        }
    }
    
    func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        DispatchQueue.main.async { [weak self] in
            self?.hasMicrophonePermission = (status == .authorized)
        }
    }
    
    func requestMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            DispatchQueue.main.async { [weak self] in
                self?.hasMicrophonePermission = true
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasMicrophonePermission = granted
                }
            }
        case .denied, .restricted:
            print("⚠️ Microphone permission denied or restricted")
            DispatchQueue.main.async { [weak self] in
                self?.hasMicrophonePermission = false
            }
        @unknown default:
            DispatchQueue.main.async { [weak self] in
                self?.hasMicrophonePermission = false
            }
        }
    }
}
#endif


