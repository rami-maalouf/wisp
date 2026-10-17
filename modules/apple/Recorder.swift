import AppKit
import AVFoundation
import Foundation
import CoreAudio

final class Recorder: ExactModule {
    private var phase = "idle"
    private var microphones: [[String: String]] = []
    private var selectedMic = ""
    private var folder: URL?
    private var scopedFolder: URL?
    private var lastFile: URL?
    private var errorText = ""
    private var inputLevel = ""
    private var level = 0.0
    private var fileWarning = ""
    private var startedAt = 0.0
    private var accumulated = 0.0
    private var seconds = 0
    private var tick: ExactTicket?
    private var capture: CaptureRecorder?
    private var startReply: ExactReply?
    private var stopReply: ExactReply?
    private var controlReply: ExactReply?
    private var floatingBar: RecordingBar?
    private var quitDone: (() -> Void)?
    private var destroyed = false
    private var panel: NSOpenPanel?
    private let libraryQueue = DispatchQueue(label: "com.rami.exact-recorder.library", qos: .utility)
    private var recents: [[String: String]] = []
    private var recentError = ""
    private var recentGeneration = 0
    private var activationObserver: NSObjectProtocol?
    private var settingsURL: URL { context.data.appendingPathComponent("recorder-settings.json") }
    private var elapsedText: String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }

    private func message(for error: Error) -> String {
        (error as? ExactNativeRefusal)?.description ?? error.localizedDescription
    }

    required init(context: ExactModuleContext) {
        super.init(context: context)
        if context.agent {
            folder = context.temporary.appendingPathComponent("recordings")
        } else {
            folder = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first?.appendingPathComponent("Exact Recordings")
            loadSettings()
        }
        refreshMicrophones()
        reloadRecents()
        if !context.agent {
            activationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.reloadRecents()
            }
        }
    }

    private func reloadRecents() {
        guard phase == "idle", let folder else { return }
        recentGeneration += 1
        let generation = recentGeneration
        let apply: (Result<[RecordingItem], Error>) -> Void = { [weak self] result in
            guard let self, !self.destroyed, self.recentGeneration == generation, self.phase == "idle" else { return }
            switch result {
            case .success(let items):
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                self.recents = items.prefix(20).map { $0.status(dateFormatter: formatter) }
                self.recentError = ""
            case .failure(let error):
                self.recents = []
                self.recentError = "Could not read this folder: \(self.message(for: error))"
            }
            self.context.changed("status")
        }
        if context.agent {
            apply(Result { try RecordingLibrary.recordings(in: folder) })
        } else {
            libraryQueue.async {
                let result = Result { try RecordingLibrary.recordings(in: folder) }
                DispatchQueue.main.async { apply(result) }
            }
        }
    }

    private func trashFile(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            if context.agent { try FileManager.default.removeItem(at: url) }
            else { try FileManager.default.trashItem(at: url, resultingItemURL: nil) }
        }
        if lastFile == url { lastFile = nil; fileWarning = "" }
        reloadRecents()
    }

    private func refreshMicrophones() {
        let devices = context.agent ? [] : CaptureRecorder.microphones()
        microphones = context.agent ? [["id": "test-mic", "name": "Test Microphone"], ["id": "test-usb", "name": "Test USB Microphone"]] : devices.map { ["id": $0.uniqueID, "name": $0.localizedName] }
        if !microphones.contains(where: { $0["id"] == selectedMic }) {
            selectedMic = context.agent ? "test-mic" : devices.first(where: { $0.transportType == kAudioDeviceTransportTypeBuiltIn })?.uniqueID ?? devices.first(where: { !Self.isBluetooth($0) })?.uniqueID ?? devices.first?.uniqueID ?? ""
        }
    }

    private static func isBluetooth(_ device: AVCaptureDevice) -> Bool {
        device.transportType == kAudioDeviceTransportTypeBluetooth || device.transportType == kAudioDeviceTransportTypeBluetoothLE
    }

    private func status() -> [String: Any] {
        ["available": true, "phase": phase, "microphones": microphones, "selectedMic": selectedMic,
         "folder": folder?.path ?? "", "elapsed": elapsedText,
         "fileName": lastFile?.lastPathComponent ?? "", "filePath": lastFile?.path ?? "", "error": errorText, "inputLevel": inputLevel, "fileWarning": fileWarning,
         "level": level, "folderName": folder?.lastPathComponent ?? "", "recents": recents, "recentError": recentError]
    }

    override func call(_ request: [String: Any]) throws -> [String: Any] {
        guard request["op"] as? String == "status" else { throw ExactNativeRefusal("Unknown recorder query.") }
        return status()
    }

    private func reply(_ reply: ExactReply?, error: String = "") {
        errorText = error
        context.changed("status")
        reply?.send(["ok": error.isEmpty, "error": error])
    }

    override func later(_ request: [String: Any], reply: ExactReply) {
        let op = request["op"] as? String ?? ""
        if phase != "idle" && !["stop", "pause", "resume", "cancel", "reveal", "open-folder"].contains(op) {
            return self.reply(reply, error: "Stop the current recording before changing its settings.")
        }
        switch op {
        case "refresh":
            refreshMicrophones()
            self.reply(reply)
        case "select":
            let id = request["id"] as? String ?? ""
            guard microphones.contains(where: { $0["id"] == id }) else { return self.reply(reply, error: "Choose an available microphone.") }
            selectedMic = id
            do { try saveSettings(); self.reply(reply) } catch { self.reply(reply, error: error.localizedDescription) }
        case "folder": chooseFolder(reply)
        case "start": start(reply)
        case "stop": stop(reply)
        case "cancel": cancel(reply)
        case "pause": pause(reply)
        case "resume": resume(reply)
        case "open-folder":
            guard let folder else { return self.reply(reply, error: "Choose a recording folder first.") }
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                if !context.agent, !NSWorkspace.shared.open(folder) { throw ExactNativeRefusal("The folder could not be opened in Finder.") }
                self.reply(reply)
            } catch { self.reply(reply, error: message(for: error)) }
        case "refresh-recents":
            reloadRecents()
            self.reply(reply)
        case "open-recent", "trash-recent":
            guard let folder else { return self.reply(reply, error: "Choose a recording folder first.") }
            do {
                let url = try RecordingLibrary.recording(id: request["id"] as? String ?? "", in: folder)
                if op == "trash-recent" { try trashFile(url) }
                else if !context.agent, !NSWorkspace.shared.open(url) { throw ExactNativeRefusal("The recording could not be opened.") }
                self.reply(reply)
            } catch {
                reloadRecents()
                self.reply(reply, error: message(for: error))
            }
        case "trash":
            guard let lastFile else { return self.reply(reply, error: "There is no saved recording to delete.") }
            do {
                try trashFile(lastFile)
                self.reply(reply)
            } catch {
                self.reply(reply, error: "Could not move the recording to Trash: \(message(for: error))")
            }
        case "reveal":
            if let lastFile, !context.agent { NSWorkspace.shared.activateFileViewerSelecting([lastFile]) }
            self.reply(reply)
        default: self.reply(reply, error: "Unknown recorder command.")
        }
    }

    private func chooseFolder(_ reply: ExactReply) {
        if context.agent {
            folder = context.temporary.appendingPathComponent("chosen-recordings")
            lastFile = nil
            fileWarning = ""
            recents = []
            reloadRecents()
            return self.reply(reply)
        }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Save Recordings Here"
        panel.message = "Choose where new audio recordings will be saved."
        panel.directoryURL = folder
        self.panel = panel
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, !self.destroyed else { return reply.fail("The recorder closed.") }
            self.panel = nil
            if response == .OK, let url = panel.url {
                self.scopedFolder?.stopAccessingSecurityScopedResource()
                self.scopedFolder = url.startAccessingSecurityScopedResource() ? url : nil
                self.folder = url
                self.lastFile = nil
                self.fileWarning = ""
                self.recents = []
                self.reloadRecents()
                do { try self.saveSettings() } catch { return self.reply(reply, error: error.localizedDescription) }
            }
            self.reply(reply)
        }
        if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }

    private func start(_ reply: ExactReply) {
        guard !selectedMic.isEmpty else { return self.reply(reply, error: "Connect a microphone, then refresh the list.") }
        phase = "starting"
        errorText = ""
        inputLevel = "Waiting for microphone signal…"
        level = 0
        lastFile = nil
        fileWarning = ""
        startReply = reply
        context.changed("status")
        if context.agent { return begin() }
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self, !self.destroyed else { return }
                guard granted else {
                    return self.failStart("Microphone access is off. Enable Wisp in System Settings > Privacy & Security > Microphone.")
                }
                do {
                    let url = try self.destination()
                    let capture = CaptureRecorder()
                    capture.started = { [weak self] in self?.begin() }
                    capture.paused = { [weak self] in self?.didPause() }
                    capture.resumed = { [weak self] in self?.didResume() }
                    capture.finished = { [weak self] url, error in self?.finish(url: url, error: error) }
                    self.capture = capture
                    capture.start(deviceID: self.selectedMic, url: url)
                } catch { self.failStart(self.message(for: error)) }
            }
        }
    }

    private func destination() throws -> URL {
        guard let folder else { throw ExactNativeRefusal("Choose a folder for your recordings.") }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard FileManager.default.isWritableFile(atPath: folder.path) else { throw ExactNativeRefusal("The selected folder is not writable. Choose another folder.") }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return folder.appendingPathComponent("Recording_\(formatter.string(from: Date()))_\(UUID().uuidString.prefix(4).lowercased()).wav")
    }

    private func begin() {
        guard !destroyed else { capture?.stop(); return }
        phase = "recording"
        seconds = 0
        accumulated = 0
        startedAt = context.now()
        if !context.agent {
            let bar = RecordingBar()
            bar.toggle = { [weak self] in
                guard let self else { return }
                if self.phase == "paused" { self.resume(nil) } else { self.pause(nil) }
            }
            bar.end = { [weak self] in self?.stop(nil) }
            bar.cancel = { [weak self] in self?.cancel(nil) }
            floatingBar = bar
            bar.show()
        }
        updateBar()
        scheduleTick()
        if let reply = startReply { startReply = nil; self.reply(reply) }
        context.changed("status")
    }

    private func scheduleTick() {
        tick = context.after(250) { [weak self] in
            guard let self, self.phase == "recording" else { return }
            let seconds = Int((self.accumulated + max(0, self.context.now() - self.startedAt)) / 1000)
            if seconds != self.seconds { self.seconds = seconds; self.updateBar(); self.context.changed("status") }
            self.capture?.readLevel { [weak self] power in
                guard let self, self.phase == "recording" else { return }
                let label = power.map { $0 > -90 ? String(format: "Input level: %.0f dB", $0) : "No microphone signal - check mute and connection" } ?? "Waiting for microphone signal…"
                let level = power.map { max(0, min(1, (Double($0) + 60) / 60)) } ?? 0
                if label != self.inputLevel || level != self.level {
                    self.inputLevel = label
                    self.level = level
                    self.context.changed("status")
                }
            }
            self.scheduleTick()
        }
    }

    private func pause(_ reply: ExactReply?) {
        guard phase == "recording" else { return self.reply(reply, error: "No recording is in progress.") }
        phase = "pausing"
        controlReply = reply
        updateBar()
        context.changed("status")
        if context.agent { didPause() } else { capture?.pause() }
    }

    private func didPause() {
        guard !destroyed, phase == "pausing" else { return }
        accumulated += max(0, context.now() - startedAt)
        seconds = Int(accumulated / 1000)
        phase = "paused"
        tick?.stop()
        tick = nil
        updateBar()
        let reply = controlReply
        controlReply = nil
        self.reply(reply)
    }

    private func resume(_ reply: ExactReply?) {
        guard phase == "paused" else { return self.reply(reply, error: "The recording is not paused.") }
        phase = "resuming"
        controlReply = reply
        updateBar()
        context.changed("status")
        if context.agent { didResume() } else { capture?.resume() }
    }

    private func didResume() {
        guard !destroyed, phase == "resuming" else { return }
        startedAt = context.now()
        phase = "recording"
        scheduleTick()
        updateBar()
        let reply = controlReply
        controlReply = nil
        self.reply(reply)
    }

    private func updateBar() {
        floatingBar?.update(phase: phase, elapsed: elapsedText)
    }

    private func stop(_ reply: ExactReply?) {
        guard phase == "recording" || phase == "paused" else { return self.reply(reply, error: "No recording is in progress.") }
        if phase == "recording" { seconds = Int((accumulated + max(0, context.now() - startedAt)) / 1000) }
        phase = "stopping"
        updateBar()
        tick?.stop()
        tick = nil
        stopReply = reply
        context.changed("status")
        if context.agent {
            do {
                let url = try destination()
                try writeAgentAudio(to: url)
                finish(url: url, error: nil)
            } catch { finish(url: nil, error: error) }
        } else { capture?.stop() }
    }

    private func cancel(_ reply: ExactReply?) {
        guard phase == "recording" || phase == "paused" else { return self.reply(reply, error: "No recording is in progress.") }
        phase = "cancelling"
        tick?.stop()
        tick = nil
        stopReply = reply
        updateBar()
        context.changed("status")
        if context.agent { finish(url: nil, error: nil) }
        else { capture?.stop(validate: false) }
    }

    private func finish(url: URL?, error: Error?) {
        guard !destroyed else { quitDone?(); quitDone = nil; return }
        var url = url
        var error = error
        if phase == "cancelling" {
            do {
                if let url, FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                }
                url = nil
                error = nil
                seconds = 0
                accumulated = 0
            } catch let discardError {
                error = ExactNativeRefusal("The recording stopped, but could not be discarded: \(message(for: discardError)). The file was kept in your chosen folder.")
            }
        }
        tick?.stop()
        tick = nil
        phase = "idle"
        inputLevel = ""
        level = 0
        floatingBar?.close()
        floatingBar = nil
        capture = nil
        errorText = error.map { "Recording could not be completed: \(message(for: $0))" } ?? ""
        if let url {
            do {
                let audio = try AVAudioFile(forReading: url)
                guard audio.length > 0 else { throw ExactNativeRefusal("No audio was received. Check the microphone and try again.") }
                lastFile = url
                fileWarning = errorText
            } catch {
                if errorText.isEmpty { errorText = message(for: error) }
            }
        }
        if let reply = startReply { startReply = nil; self.reply(reply, error: errorText) }
        if let reply = stopReply { stopReply = nil; self.reply(reply, error: errorText) }
        if let reply = controlReply { controlReply = nil; self.reply(reply, error: errorText) }
        reloadRecents()
        context.changed("status")
        quitDone?()
        quitDone = nil
    }

    private func failStart(_ message: String) {
        phase = "idle"
        if let reply = startReply { startReply = nil; self.reply(reply, error: message) }
        quitDone?()
        quitDone = nil
    }

    private func loadSettings() {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return }
        selectedMic = settings["microphone"] ?? ""
        if let path = settings["folder"] { folder = URL(fileURLWithPath: path, isDirectory: true) }
        if let encoded = settings["bookmark"], let bookmark = Data(base64Encoded: encoded) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale) {
                folder = url
                scopedFolder = url.startAccessingSecurityScopedResource() ? url : nil
            }
        }
    }

    private func saveSettings() throws {
        guard !context.agent else { return }
        var settings = ["microphone": selectedMic, "folder": folder?.path ?? ""]
        if let folder, let bookmark = try? folder.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
            settings["bookmark"] = bookmark.base64EncodedString()
        }
        try FileManager.default.createDirectory(at: context.data, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: settings).write(to: settingsURL, options: .atomic)
    }

    // the framework's agent substitutes device input; never claim this is a microphone test.
    private func writeAgentAudio(to url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = max(1, seconds) * 48000
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
        for offset in stride(from: 0, to: frames, by: 4096) {
            let count = min(4096, frames - offset)
            buffer.frameLength = AVAudioFrameCount(count)
            for i in 0..<count { buffer.floatChannelData![0][i] = Float(sin(Double(offset + i) * 440 * 2 * .pi / 48000) * 0.2) }
            try file.write(from: buffer)
        }
    }

    override func willQuit(done: @escaping () -> Void) {
        if phase == "idle" { return done() }
        quitDone = done
        tick?.stop()
        if let capture { capture.stop() }
        else { done(); quitDone = nil }
    }

    override func destroy() {
        destroyed = true
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        tick?.stop()
        panel?.cancel(nil)
        floatingBar?.close()
        capture?.stop()
        scopedFolder?.stopAccessingSecurityScopedResource()
    }
}

let exactModule: ExactModule.Type = Recorder.self
