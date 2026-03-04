// AddWordPopupController.swift — Kelime/replace hızlı ekleme paneli (NSPanel)

import AppKit
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "AddWordPopup")

@MainActor
final class AddWordPopupController: NSObject {

    private static var instance: AddWordPopupController?

    private var panel: NSPanel?
    private let wordField       = NSTextField()
    private let replacementField = NSTextField()

    // MARK: - Public

    static func show(forWord word: String = "") {
        if instance == nil {
            instance = AddWordPopupController()
        }
        instance?.show(initialWord: word)
    }

    // MARK: - Panel Setup

    private func show(initialWord: String) {
        if panel == nil {
            panel = buildPanel()
        }
        wordField.stringValue = initialWord
        replacementField.stringValue = ""
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeFirstResponder(initialWord.isEmpty ? wordField : replacementField)
    }

    private func buildPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 160),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Add to RM Dictionary"
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentView = buildContentView()
        return panel
    }

    private func buildContentView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 160))

        // Word label + field
        let wordLabel = NSTextField(labelWithString: "Word:")
        wordLabel.frame = NSRect(x: 16, y: 110, width: 80, height: 20)
        container.addSubview(wordLabel)

        wordField.frame = NSRect(x: 100, y: 108, width: 220, height: 22)
        wordField.placeholderString = "e.g. brb"
        container.addSubview(wordField)

        // Replacement label + field
        let replLabel = NSTextField(labelWithString: "Replace with:")
        replLabel.frame = NSRect(x: 16, y: 76, width: 80, height: 20)
        container.addSubview(replLabel)

        replacementField.frame = NSRect(x: 100, y: 74, width: 220, height: 22)
        replacementField.placeholderString = "e.g. be right back"
        container.addSubview(replacementField)

        // Buttons
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: 180, y: 16, width: 70, height: 28)
        container.addSubview(cancelButton)

        let addButton = NSButton(title: "Add", target: self, action: #selector(addRule))
        addButton.bezelStyle = .rounded
        addButton.keyEquivalent = "\r"
        addButton.frame = NSRect(x: 256, y: 16, width: 64, height: 28)
        container.addSubview(addButton)

        return container
    }

    // MARK: - Actions

    @objc private func addRule() {
        let word        = wordField.stringValue.trimmingCharacters(in: .whitespaces)
        let replacement = replacementField.stringValue.trimmingCharacters(in: .whitespaces)

        guard !word.isEmpty, !replacement.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Both fields are required."
            alert.runModal()
            return
        }

        Task {
            await DictionaryStore.shared.setWordRule(from: word, to: replacement)
            log.info("Added word rule: \(word) → \(replacement)")
        }
        panel?.orderOut(nil)
    }

    @objc private func cancel() {
        panel?.orderOut(nil)
    }
}
