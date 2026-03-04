// HotkeyRecorderViewController.swift — Keyboard shortcut recorder UI

import AppKit
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "HotkeyRecorder")

@MainActor
final class HotkeyRecorderViewController: NSViewController {

    // MARK: - State Machine

    private enum RecorderState {
        case idle(current: HotkeyCombo?)
        case recording
        case recorded(HotkeyCombo)
        case conflict(HotkeyCombo, String)
    }

    private var state: RecorderState = .idle(current: SettingsStore.shared.activationShortcut)
    private var eventMonitor: Any?

    // MARK: - UI Elements

    private let titleLabel       = NSTextField(labelWithString: "Global Activation Shortcut")
    private let descLabel        = NSTextField(wrappingLabelWithString:
        "Set a keyboard shortcut to activate or deactivate ReplaceMe globally.")
    private let recorderButton   = NSButton()
    private let conflictLabel    = NSTextField(labelWithString: "")
    private let clearButton      = NSButton(title: "Clear", target: nil, action: nil)
    private let saveButton       = NSButton(title: "Save", target: nil, action: nil)

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 220))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // Title
        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Description
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabelColor
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(descLabel)

        // Recorder button
        recorderButton.bezelStyle = .regularSquare
        recorderButton.isBordered = true
        recorderButton.font = .monospacedSystemFont(ofSize: 22, weight: .regular)
        recorderButton.translatesAutoresizingMaskIntoConstraints = false
        recorderButton.target = self
        recorderButton.action = #selector(recorderButtonClicked)
        view.addSubview(recorderButton)

        // Conflict/info label
        conflictLabel.font = .systemFont(ofSize: 11)
        conflictLabel.textColor = .systemRed
        conflictLabel.alignment = .center
        conflictLabel.isHidden = true
        conflictLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(conflictLabel)

        // Clear button
        clearButton.bezelStyle = .rounded
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.target = self
        clearButton.action = #selector(clearShortcut)
        view.addSubview(clearButton)

        // Save button
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.target = self
        saveButton.action = #selector(saveShortcut)
        view.addSubview(saveButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            descLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            recorderButton.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 20),
            recorderButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recorderButton.widthAnchor.constraint(equalToConstant: 240),
            recorderButton.heightAnchor.constraint(equalToConstant: 52),

            conflictLabel.topAnchor.constraint(equalTo: recorderButton.bottomAnchor, constant: 8),
            conflictLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            conflictLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

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
            if let combo = current {
                recorderButton.title = combo.displayString
                recorderButton.toolTip = "Click to change shortcut"
            } else {
                recorderButton.title = "Click to Record..."
                recorderButton.toolTip = "Click to set a shortcut"
            }
            recorderButton.contentTintColor = .labelColor
            conflictLabel.isHidden = true
            saveButton.isEnabled = false
            saveButton.title = "Save"

        case .recording:
            recorderButton.title = "● Recording..."
            recorderButton.contentTintColor = .systemOrange
            conflictLabel.isHidden = true
            saveButton.isEnabled = false
            saveButton.title = "Save"

        case .recorded(let combo):
            recorderButton.title = combo.displayString
            recorderButton.contentTintColor = .systemGreen
            conflictLabel.isHidden = true
            saveButton.isEnabled = true
            saveButton.title = "Save"

        case .conflict(let combo, let description):
            recorderButton.title = combo.displayString
            recorderButton.contentTintColor = .systemRed
            conflictLabel.stringValue = "⚠️ Conflicts with: \(description)"
            conflictLabel.isHidden = false
            saveButton.isEnabled = false
            saveButton.title = "Save"
        }
    }

    // MARK: - Actions

    @objc private func recorderButtonClicked() {
        guard case .recording = state else {
            startRecording()
            return
        }
        // Second click while recording = cancel
        stopRecording()
        state = .idle(current: SettingsStore.shared.activationShortcut)
        updateUI()
    }

    @objc private func saveShortcut() {
        guard case .recorded(let combo) = state else { return }
        SettingsStore.shared.activationShortcut = combo
        NotificationCenter.default.post(name: .rmSettingsChanged, object: nil)
        log.info("Activation shortcut saved: \(combo.displayString)")
        view.window?.close()
    }

    @objc private func clearShortcut() {
        stopRecording()
        SettingsStore.shared.activationShortcut = nil
        NotificationCenter.default.post(name: .rmSettingsChanged, object: nil)
        log.info("Activation shortcut cleared")
        view.window?.close()
    }

    // MARK: - Recording

    private func startRecording() {
        state = .recording
        updateUI()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleRecordedKey(event)
            return nil // consume event while recording
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleRecordedKey(_ event: NSEvent) {
        let keyCode    = event.keyCode
        let modifiers  = event.modifierFlags.intersection([.command, .option, .shift, .control])

        // Escape without modifiers → cancel recording
        if keyCode == 53 && modifiers.isEmpty {
            stopRecording()
            state = .idle(current: SettingsStore.shared.activationShortcut)
            updateUI()
            return
        }

        // Require at least one modifier to avoid intercepting regular typing
        guard !modifiers.isEmpty else {
            return
        }

        let combo = HotkeyCombo(keyCode: keyCode, modifiers: modifiers)
        stopRecording()

        if let conflict = SystemShortcutChecker.conflictDescription(for: combo) {
            state = .conflict(combo, conflict)
            log.warning("Hotkey conflict: \(combo.displayString) → \(conflict)")
        } else {
            state = .recorded(combo)
            log.info("Hotkey recorded: \(combo.displayString)")
        }
        updateUI()
    }

    // MARK: - Cleanup

    override func viewWillDisappear() {
        super.viewWillDisappear()
        stopRecording()
    }
}
