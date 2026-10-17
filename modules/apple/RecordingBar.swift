import AppKit

final class RecordingBar: NSObject {
    var toggle: (() -> Void)?
    var end: (() -> Void)?
    var cancel: (() -> Void)?
    private let panel: NSPanel
    private let timer = NSTextField(labelWithString: "00:00")
    private let state = NSTextField(labelWithString: "REC")
    private let pauseButton = NSButton(title: "Pause", target: nil, action: nil)
    private let endButton = NSButton(title: "End", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)

    override init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 430, height: 60), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.title = "Recording Controls"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        let background = NSVisualEffectView(frame: panel.contentView!.bounds)
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 18
        panel.contentView = background
        timer.font = .monospacedDigitSystemFont(ofSize: 22, weight: .medium)
        timer.setAccessibilityLabel("Recording time")
        state.font = .systemFont(ofSize: 11, weight: .bold)
        state.textColor = .systemRed
        state.setContentHuggingPriority(.defaultLow, for: .horizontal)
        pauseButton.bezelStyle = .rounded
        pauseButton.target = self
        pauseButton.action = #selector(toggleRecording)
        pauseButton.setAccessibilityIdentifier("floating-pause")
        endButton.bezelStyle = .rounded
        endButton.contentTintColor = .systemRed
        endButton.target = self
        endButton.action = #selector(endRecording)
        endButton.setAccessibilityIdentifier("floating-end")
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelRecording)
        cancelButton.toolTip = "Cancel this recording and move its file to Trash"
        cancelButton.setAccessibilityIdentifier("floating-cancel")
        let row = NSStackView(views: [state, timer, pauseButton, endButton, cancelButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 14
        row.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -18),
            row.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            timer.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
        ])
    }

    func show() {
        if let frame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.maxX - panel.frame.width - 24, y: frame.maxY - panel.frame.height - 24))
        }
        panel.orderFrontRegardless()
    }

    func update(phase: String, elapsed: String) {
        timer.stringValue = elapsed
        state.stringValue = phase == "paused" ? "PAUSED" : phase == "stopping" ? "SAVING" : phase == "cancelling" ? "CANCEL" : "REC"
        state.textColor = phase == "paused" ? .secondaryLabelColor : .systemRed
        pauseButton.title = phase == "paused" ? "Resume" : "Pause"
        pauseButton.isEnabled = phase == "recording" || phase == "paused"
        endButton.isEnabled = pauseButton.isEnabled
        cancelButton.isEnabled = pauseButton.isEnabled
    }

    func close() { panel.close() }
    @objc private func toggleRecording() { toggle?() }
    @objc private func endRecording() { end?() }
    @objc private func cancelRecording() { cancel?() }
}
