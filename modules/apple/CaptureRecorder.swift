import AVFoundation
import Foundation

final class CaptureRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let queue = DispatchQueue(label: "com.rami.exact-recorder.capture")
    private var session: AVCaptureSession?
    private var output: AVCaptureAudioDataOutput?
    private var observer: NSObjectProtocol?
    private var file: AVAudioFile?
    private var destination: URL?
    private let normalizer = PCMNormalizer()
    private var completed = false
    private var didStart = false
    private var isPaused = false
    private var power: Float?
    private var receivedSignal = false
    var started: (() -> Void)?
    var paused: (() -> Void)?
    var resumed: (() -> Void)?
    var finished: ((URL, Error?) -> Void)?

    static func microphones() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified).devices
    }

    func start(deviceID: String, url: URL) {
        queue.async { [self] in
            destination = url
            do {
                guard !completed else { return }
                guard let device = Self.microphones().first(where: { $0.uniqueID == deviceID }) else {
                    throw ExactNativeRefusal("The selected microphone is disconnected. Refresh the list and choose another microphone.")
                }
                let session = AVCaptureSession()
                let input = try AVCaptureDeviceInput(device: device)
                let output = AVCaptureAudioDataOutput()
                guard session.canAddInput(input), session.canAddOutput(output) else {
                    throw ExactNativeRefusal("This microphone cannot be used for recording.")
                }
                session.beginConfiguration()
                session.addInput(input)
                session.addOutput(output)
                output.setSampleBufferDelegate(self, queue: queue)
                session.commitConfiguration()
                self.session = session
                self.output = output
                observer = NotificationCenter.default.addObserver(forName: .AVCaptureSessionRuntimeError, object: session, queue: nil) { [weak self] note in
                    let error = note.userInfo?[AVCaptureSessionErrorKey] as? Error ?? ExactNativeRefusal("Microphone capture was interrupted.")
                    self?.queue.async { [weak self] in self?.complete(error: error) }
                }
                session.startRunning()
                guard session.isRunning else { throw ExactNativeRefusal("The microphone could not start.") }
                queue.asyncAfter(deadline: .now() + 5) { [weak self] in
                    guard let self, !self.didStart, !self.completed else { return }
                    self.complete(error: ExactNativeRefusal("The microphone did not send audio. Check its connection and permission, then try again."))
                }
            } catch { complete(error: error) }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !completed, !isPaused, let destination else { return }
        do {
            guard let description = sampleBuffer.formatDescription,
                  let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description),
                  let format = AVAudioFormat(streamDescription: asbd),
                  sampleBuffer.numSamples > 0,
                  let raw = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleBuffer.numSamples)) else {
                throw ExactNativeRefusal("The microphone sent an invalid audio buffer.")
            }
            raw.frameLength = AVAudioFrameCount(sampleBuffer.numSamples)
            let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, at: 0, frameCount: Int32(sampleBuffer.numSamples), into: raw.mutableAudioBufferList)
            guard status == noErr else { throw ExactNativeRefusal("Could not read the microphone samples (\(status)).") }
            let buffer = try normalizer.normalize(raw)
            if file == nil {
                file = try AVAudioFile(forWriting: destination, settings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: buffer.format.sampleRate,
                    AVNumberOfChannelsKey: buffer.format.channelCount,
                    AVLinearPCMBitDepthKey: 24,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false,
                ])
            }
            guard let file, file.processingFormat == buffer.format else {
                throw ExactNativeRefusal("The microphone changed sample rate or channel count. The recording was stopped to preserve its audio.")
            }
            try file.write(from: buffer)
            var energy = 0.0
            let frames = Int(buffer.frameLength)
            let channels = Int(buffer.format.channelCount)
            for channel in 0..<channels {
                for frame in 0..<frames {
                    let sample = Double(buffer.floatChannelData![channel][frame])
                    energy += sample * sample
                }
            }
            receivedSignal = receivedSignal || energy > 0
            power = Float(10 * log10(max(1e-16, energy / Double(max(1, frames * channels)))))
            if !didStart {
                didStart = true
                DispatchQueue.main.async { self.started?() }
            }
        } catch { complete(error: error) }
    }

    func stop() { queue.async { self.complete(error: nil) } }

    func pause() {
        queue.async {
            guard !self.completed, self.didStart, !self.isPaused else { return }
            self.isPaused = true
            DispatchQueue.main.async { self.paused?() }
        }
    }

    func resume() {
        queue.async {
            guard !self.completed, self.isPaused else { return }
            self.isPaused = false
            DispatchQueue.main.async { self.resumed?() }
        }
    }

    func readLevel(_ receive: @escaping (Float?) -> Void) {
        queue.async {
            let power = self.power
            DispatchQueue.main.async { receive(power) }
        }
    }

    private func complete(error: Error?) {
        guard !completed, let destination else { return }
        completed = true
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        output?.setSampleBufferDelegate(nil, queue: nil)
        session?.stopRunning()
        session = nil
        output = nil
        file = nil
        var resultError = error
        if resultError == nil {
            do {
                if try !receivedSignal || !AudioSignal.containsSignal(at: destination) {
                    resultError = ExactNativeRefusal("No microphone signal was recorded. Check the microphone's mute switch and connection. Any recording file was kept in your chosen folder.")
                }
            } catch { resultError = error }
        }
        let finalError = resultError
        DispatchQueue.main.async { self.finished?(destination, finalError) }
    }
}
