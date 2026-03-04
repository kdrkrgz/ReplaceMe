// HotkeyRecorderViewController.swift — Keyboard shortcut recorder UI

import AppKit
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "HotkeyRecorder")

@MainActor
final class HotkeyRecorderViewController: NSViewController {

    // MARK: - State Machine
    // Conflict is no longer a blocking state — handled via NSAlert confirmation.

    private enum RecorderState {
        case idle(current: [HotkeyCombo])
        case recording(accumulated: [HotkeyCombo])  // partial strokes so far
        case recorded([HotkeyCombo])                 // ready to save
    }

    private var state: RecorderState = .idle(current: SettingsStore.shared.activationShortcut)
    private var eventMonitor: Any?

    // MARK: - UI Elements

    private let titleLabel       = NSTextField(labelWithString: "Global Activation Shortcut")
    private let descLabel        = NSTextField(wrappingLabelWithString:
        "Set a keyboard shortcut (up to 3 strokes) to toggle ReplaceMe globally.")
    private let recorderButton   = NSButton()
    private let hintLabel        = NSTextField(labelWithString: "")
    private let clearButton      = NSButton(title: "Clear", target: nil, action: nil)
    private let saveButton       = NSButton(title: "Save", target: nil, action: nil)

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 230))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateUI()
    }

    // MARK: - Setup

    private func setupUI() {
        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabelColor
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(descLabel)

        recorderButton.bezelStyle = .regularSquare
        recorderButton.isBordered = true
        recorderButton.font = .monospacedSystemFont(ofSize: 20, weight: .regular)
        recorderButton.translatesAutoresizingMaskIntoConstraints = false
        recorderButton.target = self
        recorderButton.action = #selector(recorderButtonClicked)
        view.addSubview(recorderButton)

        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        clearButton.bezelStyle = .rounded
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.target = self
        clearButton.action = #selector(clearShortcut)
        view.addSubview(clearButton)

        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.target = self
        saveButton.action = #selector(saveShortcut)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            descLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            recorderButton.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 20),
            recorderButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recorderButton.widthAnchor.constraint(equalToConstant: 280),
            recorderButton.heightAnchor.constraint(equalToConstant: 52),

            hintLabel.topAnchor.constraint(equalTo: recorderButton.bottomAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            clearButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -12),
            clearButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            clearButton.widthAnchor.constraint(equalToConstant: 90),

            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            saveButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            saveButton.widthAnchor.constraint(equalToConstant: 90),
        ])
    }

    // MARK: - UI State

    private func updateUI() {
        switch state {
        case .idle(let current):
            if current.isEmpty {
                recorderButton.title = "Click to Record..."
                recorderButton.toolTip = "Click to set an activation shortcut"
            } else {
                recorderButton.title = sequenceDisplay(current)
                recorderButton.toolTip = "Click to change shortcut"
            }
            recorderButton.contentTintColor = .labelColor
            hintLabel.stringValue = "Press up to 3 key combinations in sequence."
            saveButton.isEnabled = false

        case .recording(let accumulated):
            if accumulated.isEmpty {
                recorderButton.title = "● Recording..."
            } else {
                recorderButton.title = sequenceDisplay(accumulated) + " ●"
            }
            recorderButton.contentTintColor = .systemOrange
            let remaining = 3 - accumulated.count
            if accumulated.isEmpty {
                hintLabel.stringValue = "Press a key combo (with modifier). Esc to cancel."
            } else {
                hintLabel.stringValue = "\(accumulated.count)/3 recorded. Press \(remaining) more, or click button to finish."
            }
            saveButton.isEnabled = false

        case .recorded(let strokes):
            recorderButton.title = sequenceDisplay(strokes)
            recorderButton.contentTintColor = .systemGreen
            hintLabel.stringValue = "\(strokes.count) stroke\(strokes.count == 1 ? "" : "s") recorded. Click Save to apply."
            saveButton.isEnabled = true
        }
    }

    private func sequenceDisplay(_ strokes: [HotkeyCombo]) -> String {
        strokes.map { $0.displayString }.joined(separator: " → ")
    }

    // MARK: - Actions

    @objc private func recorderButtonClicked() {
        switch state {
        case .idle:
            startRecording()

        case .recording(let accumulated):
            stopRecording()
            if accumulated.isEmpty {
                state = .idle(current: SettingsStore.shared.activationShortcut)
                updateUI()
            } else {
                finishRecording(strokes: accumulated)
            }

        case .recorded:
            // Restart recording from scratch
            startRecording()
        }
    }

    @objc private func saveShortcut() {
        guard case .recorded(let strokes) = state else { return }
        SettingsStore.shared.activationShortcut = strokes
        NotificationCenter.default.post(name: .rmSettingsChanged, object: nil)
        log.info("Activation shortcut saved: \(self.sequenceDisplay(strokes))")
        view.window?.close()
    }

    @objc private func clearShortcut() {
        stopRecording()
        SettingsStore.shared.activationShortcut = []
        NotificationCenter.default.post(name: .rmSettingsChanged, object: nil)
        log.info("Activation shortcut cleared")
        view.window?.close()
    }

    // MARK: - Recording

    private func startRecording() {
        state = .recording(accumulated: [])
        updateUI()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleRecordedKey(event)
            return nil // consume all keys while recording
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleRecordedKey(_ event: NSEvent) {
        guard case .recording(var accumulated) = state else { return }

        let keyCode   = event.keyCode
        let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])

        // Escape without modifiers → cancel recording
        if keyCode == 53 && modifiers.isEmpty {
            stopRecording()
            state = .idle(current: SettingsStore.shared.activationShortcut)
            updateUI()
            return
        }

        // Each stroke must have at least one modifier key
        guard !modifiers.isEmpty else { return }

        let stroke = HotkeyCombo(keyCode: keyCode, modifiers: modifiers)
        accumulated.append(stroke)

        if accumulated.count >= 3 {
            stopRecording()
            finishRecording(strokes: accumulated)
        } else {
            state = .recording(accumulated: accumulated)
            updateUI()
        }
    }

    /// Validates strokes for system conflicts and either saves or asks for confirmation.
    private func finishRecording(strokes: [HotkeyCombo]) {
        // Only check the first stroke; multi-stroke sequences are safe from system shortcuts.
        if let firstStroke = strokes.first,
           let conflict = SystemShortcutChecker.conflictDescription(for: firstStroke) {
            log.warning("Conflict detected: \(self.sequenceDisplay(strokes)) → \(conflict)")
            showConflictAlert(for: strokes, conflictDescription: conflict)
        } else {
            state = .recorded(strokes)
            updateUI()
        }
    }

    /// Shows an NSAlert asking the user whether to override the conflicting shortcut.
    private func showConflictAlert(for strokes: [HotkeyCombo], conflictDescription: String) {
        let alert = NSAlert()
        alert.messageText = "System Shortcut Conflict"
        alert.informativeText = """
            "\(sequenceDisplay(strokes))" may conflict with the system shortcut "\(conflictDescription)".

            Saving this shortcut may interfere with the system function. Do you want to use it anyway?
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Use Anyway")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            state = .recorded(strokes)
            log.info("User chose to override conflict: \(self.sequenceDisplay(strokes))")
        } else {
            // Back to idle — let user try a different shortcut
            state = .idle(current: SettingsStore.shared.activationShortcut)
            log.info("User cancelled conflicting shortcut")
        }
        updateUI()
    }

    // MARK: - Cleanup

    override func viewWillDisappear() {
        super.viewWillDisappear()
        stopRecording()
    }
}

