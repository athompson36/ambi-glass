import Foundation
import Accelerate
import AVFoundation
import Combine

struct ABMatrix {
    var m: [Float] = [1,0,0,0,
                      0,1,0,0,
                      0,0,1,0,
                      0,0,0,1]
}

final class AmbisonicsDSP: ObservableObject {
    var matrix = ABMatrix()

    init() {
        loadDefaultMicProfile()
    }

    private struct MicProfileLite: Decodable {
        let matrix: [Float]?
        let capsuleTrims_dB: [Float]?
    }

    private func loadDefaultMicProfile() {
        // Try to load Resources/Presets/AmbiAlice_v1.json from the app bundle; fall back to identity
        // Use guard to safely access Bundle.main in test environment
        guard let bundle = Bundle.main.url(forResource: "AmbiAlice_v1", withExtension: "json", subdirectory: "Presets") ??
                            Bundle.main.url(forResource: "AmbiAlice_v1", withExtension: "json") else {
            // Fall back to identity matrix (already set as default)
            return
        }
        
        guard let data = try? Data(contentsOf: bundle),
              let prof = try? JSONDecoder().decode(MicProfileLite.self, from: data) else {
            return
        }
        
        if let arr = prof.matrix, arr.count == 16 {
            matrix.m = arr
        }
        if let trims = prof.capsuleTrims_dB, trims.count == 4 {
            capsuleTrims_dB = trims.map { Float($0) }
        }
    }

    // Orientation in radians (yaw: Z, pitch: Y, roll: X)
    var yaw: Float = 0
    var pitch: Float = 0
    var roll: Float = 0

    func setOrientationDegrees(yaw: Double, pitch: Double, roll: Double) {
        self.yaw = Float(yaw * .pi / 180.0)
        self.pitch = Float(pitch * .pi / 180.0)
        self.roll = Float(roll * .pi / 180.0)
    }

    // Per-capsule trims (dB) applied to A-format channels before matrix
    var capsuleTrims_dB: [Float] = [0,0,0,0]
    // Interface channel gain offsets (dB) from calibration
    var interfaceGains_dB: [Float] = [0,0,0,0]
    private func linearGains(from dB: [Float]) -> [Float] {
        guard dB.count == 4 else { return [1,1,1,1] }
        return dB.map { powf(10.0, $0/20.0) }
    }

    func processAtoB(aBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: aBuffer.format.sampleRate, channels: 4, interleaved: false),
              let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: aBuffer.frameCapacity) else {
            print("❌ AmbisonicsDSP: Failed to create output buffer, returning input unchanged")
            return aBuffer
        }
        out.frameLength = aBuffer.frameLength
        let n = Int(aBuffer.frameLength)

        let a0 = aBuffer.floatChannelData![0]
        let a1 = aBuffer.floatChannelData![1]
        let a2 = aBuffer.floatChannelData![2]
        let a3 = aBuffer.floatChannelData![3]
        let W = out.floatChannelData![0]
        let Y = out.floatChannelData![1]
        let Z = out.floatChannelData![2]
        let X = out.floatChannelData![3]

        let m = matrix.m
        let trims = linearGains(from: capsuleTrims_dB)
        let iface = linearGains(from: interfaceGains_dB)
        let g0 = trims[0] * iface[0]
        let g1 = trims[1] * iface[1]
        let g2 = trims[2] * iface[2]
        let g3 = trims[3] * iface[3]
        for i in 0..<n {
            let v0 = a0[i]*g0, v1 = a1[i]*g1, v2 = a2[i]*g2, v3 = a3[i]*g3
            W[i] = m[0]*v0 + m[1]*v1 + m[2]*v2 + m[3]*v3
            Y[i] = m[4]*v0 + m[5]*v1 + m[6]*v2 + m[7]*v3
            Z[i] = m[8]*v0 + m[9]*v1 + m[10]*v2 + m[11]*v3
            X[i] = m[12]*v0 + m[13]*v1 + m[14]*v2 + m[15]*v3
        }

        if yaw != 0 || pitch != 0 || roll != 0 {
            let cy = cosf(yaw), sy = sinf(yaw)
            let cp = cosf(pitch), sp = sinf(pitch)
            let cr = cosf(roll), sr = sinf(roll)
            // R = Rz(yaw) * Ry(pitch) * Rx(roll)
            let r00 = cy*cp
            let r01 = cy*sp*sr - sy*cr
            let r02 = cy*sp*cr + sy*sr
            let r10 = sy*cp
            let r11 = sy*sp*sr + cy*cr
            let r12 = sy*sp*cr - cy*sr
            let r20 = -sp
            let r21 = cp*sr
            let r22 = cp*cr

            // Channels: out is W,Y,Z,X (AmbiX). Rotate [X,Y,Z].
            for i in 0..<n {
                let x = X[i]
                let y = Y[i]
                let z = Z[i]
                let xr = r00*x + r01*y + r02*z
                let yr = r10*x + r11*y + r12*z
                let zr = r20*x + r21*y + r22*z
                X[i] = xr
                Y[i] = yr
                Z[i] = zr
            }
        }
        return out
    }
}
