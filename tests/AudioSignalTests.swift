import AVFoundation

@main
struct AudioSignalTests {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192)!
        buffer.frameLength = 8192
        for channel in 0..<2 {
            for frame in 0..<8192 { buffer.floatChannelData![channel][frame] = 0 }
        }
        let silent = directory.appendingPathComponent("silent.wav")
        try write(buffer, to: silent)
        let silentResult = try AudioSignal.containsSignal(at: silent)
        precondition(!silentResult, "all-zero audio must be detected as silent")
        buffer.floatChannelData![1][8191] = 0.01
        let signal = directory.appendingPathComponent("signal.wav")
        try write(buffer, to: signal)
        let signalResult = try AudioSignal.containsSignal(at: signal)
        precondition(signalResult, "signal in a later buffer and second channel must be detected")
        try verifyShurePCM(in: directory)
        print("audio signal tests passed")
    }

    static func write(_ buffer: AVAudioPCMBuffer, to url: URL) throws {
        var settings = buffer.format.settings
        settings[AVLinearPCMIsNonInterleaved] = false
        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
    }

    static func verifyShurePCM(in directory: URL) throws {
        var asbd = AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsAlignedHigh,
            mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
            mChannelsPerFrame: 1, mBitsPerChannel: 24, mReserved: 0)
        let format = AVAudioFormat(streamDescription: &asbd)!
        let raw = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        raw.frameLength = 512
        let samples = raw.mutableAudioBufferList.pointee.mBuffers.mData!.assumingMemoryBound(to: Int32.self)
        for frame in 0..<512 { samples[frame] = Int32(sin(Double(frame) * 0.1) * 0.2 * Double(Int32.max)) & ~255 }
        let normalizer = PCMNormalizer()
        let initialFloat = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!, frameCapacity: 512)!
        initialFloat.frameLength = 512
        for frame in 0..<512 { initialFloat.floatChannelData![0][frame] = 0.125 }
        let initialResult = try normalizer.normalize(initialFloat)
        precondition(initialResult.floatChannelData![0][0] == 0.125)
        let normalized = try normalizer.normalize(raw)
        let url = directory.appendingPathComponent("shure-layout.wav")
        do {
            let file = try AVAudioFile(forWriting: url, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 24,
                AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ])
            try file.write(from: normalized)
            // the next capture buffer may switch from integer pcm to float pcm.
            try file.write(from: normalizer.normalize(normalized))
        }
        let file = try AVAudioFile(forReading: url)
        let result = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 1024)!
        try file.read(into: result)
        precondition(result.frameLength == 1024)
        for frame in 0..<1024 {
            let expected = sin(Double(frame % 512) * 0.1) * 0.2
            precondition(abs(Double(result.floatChannelData![0][frame]) - expected) < 0.000001,
                "24-bit samples in 4-byte storage and subsequent float samples must retain their amplitudes in WAV")
        }
    }
}
