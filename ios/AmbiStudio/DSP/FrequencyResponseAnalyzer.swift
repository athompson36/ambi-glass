import Foundation
import Accelerate

struct FrequencyResponseAnalyzer {
    // Analyze frequency response using FFT
    func analyzeFrequencyResponse(
        signal: [Float],
        sampleRate: Double,
        windowSize: Int = 4096,
        hopSize: Int = 2048
    ) -> MicCalCurve {
        var freqs: [Double] = []
        var gains: [Double] = []
        
        // Use FFT to analyze frequency response
        let n = windowSize
        let fftSize = 1 << Int(ceil(log2(Double(n))))
        
        // Create window (Hann window)
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        
        // Process signal in overlapping windows
        var position = 0
        var magnitudeSum: [Float] = Array(repeating: 0, count: fftSize / 2)
        var windowCount = 0
        
        while position + n <= signal.count {
            // Extract window
            var windowed = Array(signal[position..<position + n])
            
            // Apply window
            var windowedResult = [Float](repeating: 0, count: n)
            vDSP_vmul(&windowed, 1, &window, 1, &windowedResult, 1, vDSP_Length(n))
            windowed = windowedResult
            
            // Zero-pad to FFT size
            var padded = windowed + [Float](repeating: 0, count: fftSize - n)
            
            // FFT
            var splitReal = [Float](repeating: 0, count: fftSize / 2)
            var splitImag = [Float](repeating: 0, count: fftSize / 2)
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            
            padded.withUnsafeMutableBytes { ptr in
                let buf = ptr.bindMemory(to: DSPComplex.self)
                splitReal.withUnsafeMutableBufferPointer { realPtr in
                    splitImag.withUnsafeMutableBufferPointer { imagPtr in
                        var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                        vDSP_ctoz(buf.baseAddress!, 2, &split, 1, vDSP_Length(fftSize / 2))
                        
                        let log2n = vDSP_Length(log2(Double(fftSize)))
                        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(FFT_RADIX2)) else {
                            return
                        }
                        
                        vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                        
                        // Calculate magnitude
                        magnitudes.withUnsafeMutableBufferPointer { magPtr in
                            vDSP_zvmags(&split, 1, magPtr.baseAddress!, 1, vDSP_Length(fftSize / 2))
                        }
                        
                        vDSP_destroy_fftsetup(setup)
                    }
                }
            }
            
            // Accumulate
            var tempSum = magnitudeSum
            vDSP_vadd(&tempSum, 1, &magnitudes, 1, &magnitudeSum, 1, vDSP_Length(fftSize / 2))
            windowCount += 1
            position += hopSize
        }
        
        // Average
        if windowCount > 0 {
            var scale = 1.0 / Float(windowCount)
            var tempAvg = magnitudeSum
            vDSP_vsmul(&tempAvg, 1, &scale, &magnitudeSum, 1, vDSP_Length(fftSize / 2))
        }
        
        // Convert to dB and extract frequency bins
        let nyquist = sampleRate / 2.0
        let binWidth = sampleRate / Double(fftSize)
        
        for i in 1..<(fftSize / 2) {
            let freq = Double(i) * binWidth
            if freq >= 20 && freq <= 20000 { // Audio range
                let magnitude = magnitudeSum[i]
                let magnitudeDB = magnitude > 0 ? 20.0 * log10(Double(magnitude)) : -120.0
                freqs.append(freq)
                gains.append(magnitudeDB)
            }
        }
        
        return MicCalCurve(freqs: freqs, gains: gains)
    }
    
    // Compare two frequency responses and generate calibration curve
    func generateCalibrationCurve(
        reference: MicCalCurve,
        measured: MicCalCurve
    ) -> MicCalCurve {
        var calFreqs: [Double] = []
        var calGains: [Double] = []
        
        // Interpolate both curves to common frequency points
        let minFreq = max(reference.freqs.first ?? 20, measured.freqs.first ?? 20)
        let maxFreq = min(reference.freqs.last ?? 20000, measured.freqs.last ?? 20000)
        
        // Generate log-spaced frequency points
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let numPoints = 200 // Number of calibration points
        
        for i in 0..<numPoints {
            let logFreq = logMin + Double(i) * (logMax - logMin) / Double(numPoints - 1)
            let freq = pow(10.0, logFreq)
            
            let refGain = reference.gainAt(freq: freq)
            let measGain = measured.gainAt(freq: freq)
            
            // Calibration gain = reference - measured (to correct measured to match reference)
            let calGain = refGain - measGain
            
            calFreqs.append(freq)
            calGains.append(calGain)
        }
        
        return MicCalCurve(freqs: calFreqs, gains: calGains)
    }
    
    // Generate calibration curve for each Ambi-Alice capsule
    func generateCapsuleCalibrations(
        reference: [Float],
        ambiAlice: [[Float]],
        sampleRate: Double
    ) -> [MicCalCurve] {
        // Analyze reference mic
        let referenceCurve = analyzeFrequencyResponse(
            signal: reference,
            sampleRate: sampleRate
        )
        
        // Analyze each Ambi-Alice capsule
        var capsuleCurves: [MicCalCurve] = []
        for capsule in ambiAlice {
            let capsuleCurve = analyzeFrequencyResponse(
                signal: capsule,
                sampleRate: sampleRate
            )
            
            // Generate calibration curve for this capsule
            let calCurve = generateCalibrationCurve(
                reference: referenceCurve,
                measured: capsuleCurve
            )
            
            capsuleCurves.append(calCurve)
        }
        
        return capsuleCurves
    }
}

