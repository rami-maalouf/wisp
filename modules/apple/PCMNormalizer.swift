import AVFoundation

final class PCMNormalizer {
    private var converter: AVAudioConverter?

    func normalize(_ input: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: input.format.sampleRate, channels: input.format.channelCount),
              let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: input.frameLength) else {
            throw NSError(domain: "PCMNormalizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "The microphone supplied an unsupported audio format."])
        }
        // capture devices can change their pcm layout between successive buffers.
        if converter?.inputFormat != input.format {
            converter = AVAudioConverter(from: input.format, to: format)
        }
        guard let converter else {
            throw NSError(domain: "PCMNormalizer", code: 2, userInfo: [NSLocalizedDescriptionKey: "The microphone audio could not be converted."])
        }
        try converter.convert(to: output, from: input)
        return output
    }
}
