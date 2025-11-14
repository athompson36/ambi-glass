import Foundation
import AVFoundation
import Combine

/// Protocol for audio recording implementations
/// Allows platform-specific implementations (Core Audio for macOS, AVAudioEngine for iOS)
protocol AudioRecorderProtocol: AnyObject {
    // Configuration
    var selectedDeviceID: String { get set }
    var selectedInputChannels: [Int] { get set }
    var requestedSampleRate: Double { get set }
    var recordingFormat: RecordingFormat { get set }
    
    // State
    var currentSampleRate: Double { get }
    var isMonitoring: Bool { get }
    var hasMicrophonePermission: Bool { get }
    
    // Meters
    var meterPublisher: AnyPublisher<[CGFloat], Never> { get }
    
    // Methods
    func startMonitoring(sampleRate: Double?, bufferFrames: AVAudioFrameCount) async
    func stopMonitoring() async
    func start(sampleRate: Double, bufferFrames: AVAudioFrameCount) async throws
    func stop()
    func checkMicrophonePermission()
    func requestMicrophonePermission()
    
    // Callbacks for processing audio buffers
    var onBufferReceived: ((AVAudioPCMBuffer) -> Void)? { get set }
}

