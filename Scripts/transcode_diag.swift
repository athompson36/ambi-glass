import Foundation
import AVFoundation

func testFormat(_ sr: Double) {
    let ok1 = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sr, channels: 4, interleaved: false) != nil
    let ok2 = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 4) != nil
    print("rate=\(sr): common=\(ok1) standard=\(ok2)")
    if let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sr, channels: 2, interleaved: true) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("diag_\(Int(sr)).wav")
        do {
            let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
            let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 1024)!
            buf.frameLength = 1024
            try file.write(from: buf)
            print("write test ok -> \(url.path)")
        } catch {
            print("write test failed: \(error)")
        }
    } else {
        print("could not create 2ch interleaved format for write test")
    }
}

for sr in [44100.0, 48000.0, 88200.0, 96000.0, 176400.0, 192000.0] { testFormat(sr) }
