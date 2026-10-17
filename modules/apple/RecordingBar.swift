import AppKit

final class RecordingBar: NSObject {
    var toggle: (() -> Void)?
    var end: (() -> Void)?
    var cancel: (() -> Void)?
    private let panel: NSPanel
    private let timer = NSTextField(labelWithString: "00:00")
    private let state = NSImageView()
    private let pauseButton = NSButton(title: "", target: nil, action: nil)
    private let endButton = NSButton(title: "Finish", target: nil, action: nil)
    private let cancelButton = NSButton(title: "", target: nil, action: nil)

    override init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 310, height: 52), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
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
        background.layer?.cornerRadius = 14
        panel.contentView = background
        timer.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        timer.setAccessibilityLabel("Recording time")
        state.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Recording")
        state.contentTintColor = .systemRed
        pauseButton.bezelStyle = .rounded
        pauseButton.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Pause recording")
        pauseButton.imagePosition = .imageOnly
        pauseButton.toolTip = "Pause recording"
        pauseButton.target = self
        pauseButton.action = #selector(toggleRecording)
        pauseButton.setAccessibilityIdentifier("floating-pause")
        endButton.bezelStyle = .rounded
        endButton.contentTintColor = .systemRed
        endButton.target = self
        endButton.action = #selector(endRecording)
        endButton.setAccessibilityIdentifier("floating-end")
        cancelButton.bezelStyle = .rounded
        cancelButton.isBordered = false
        cancelButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Cancel recording")
        cancelButton.imagePosition = .imageOnly
        cancelButton.target = self
        cancelButton.action = #selector(cancelRecording)
        cancelButton.toolTip = "Cancel this recording and move its file to Trash"
        cancelButton.setAccessibilityIdentifier("floating-cancel")
        let separator = NSBox()
        separator.boxType = .separator
        let row = NSStackView(views: [state, timer, pauseButton, endButton, separator, cancelButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),
            row.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            timer.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
            state.widthAnchor.constraint(equalToConstant: 8),
            state.heightAnchor.constraint(equalToConstant: 8),
            pauseButton.widthAnchor.constraint(equalToConstant: 32),
            cancelButton.widthAnchor.constraint(equalToConstant: 24),
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: 20),
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
        state.contentTintColor = phase == "paused" ? .systemOrange : .systemRed
        state.setAccessibilityLabel(phase == "paused" ? "Paused" : phase == "stopping" ? "Saving" : phase == "cancelling" ? "Cancelling" : "Recording")
        let pauseLabel = phase == "paused" ? "Resume recording" : "Pause recording"
        pauseButton.image = NSImage(systemSymbolName: phase == "paused" ? "play.fill" : "pause.fill", accessibilityDescription: pauseLabel)
        pauseButton.setAccessibilityLabel(pauseLabel)
        pauseButton.toolTip = pauseLabel
        pauseButton.isEnabled = phase == "recording" || phase == "paused"
        endButton.isEnabled = pauseButton.isEnabled
        cancelButton.isEnabled = pauseButton.isEnabled
    }

    func close() { panel.close() }
    @objc private func toggleRecording() { toggle?() }
    @objc private func endRecording() { end?() }
    @objc private func cancelRecording() { cancel?() }
}
