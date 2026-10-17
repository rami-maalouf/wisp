import AVFoundation

enum AudioSignal {
    static func containsSignal(at url: URL) throws -> Bool {
        let file = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096) else {
            throw NSError(domain: "AudioSignal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not inspect the recorded audio."])
        }
        while file.framePosition < file.length {
            try file.read(into: buffer)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
            for channel in 0..<Int(buffer.format.channelCount) {
                for frame in 0..<Int(buffer.frameLength) {
                    if channels[channel][frame] != 0 { return true }
                }
            }
        }
        return false
    }
}
