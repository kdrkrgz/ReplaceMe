// SettingsViewController.swift — Letter + Word replace kural editörü

import AppKit
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "Settings")

@MainActor
final class SettingsViewController: NSViewController {

    // MARK: - UI Elements

    private let letterLabel      = NSTextField(labelWithString: "Letter Replace (format: from,to — one per line)")
    private let letterScrollView  = NSScrollView()
    private let letterTextView   = NSTextView()
    private let letterCICheckbox = NSButton(checkboxWithTitle: "Case Insensitive", target: nil, action: nil)
    private let letterWarningLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = NSColor.systemOrange
        label.isHidden = true
        return label
    }()

    private let wordLabel        = NSTextField(labelWithString: "Word Replace (format: from,to — one per line)")
    private let wordScrollView    = NSScrollView()
    private let wordTextView     = NSTextView()
    private let wordCICheckbox   = NSButton(checkboxWithTitle: "Case Insensitive", target: nil, action: nil)

    private let importButton     = NSButton(title: "Import CSV", target: nil, action: nil)
    private let exportButton     = NSButton(title: "Export CSV", target: nil, action: nil)
    private let saveButton       = NSButton(title: "Save", target: nil, action: nil)

    private var saveDebounceTask: Task<Void, Never>?

    /// İlk odaklanılacak view — SettingsWindowController tarafından first responder yapılır.
    var firstEditableView: NSView { letterTextView }

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 540))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadRules()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Letter section
        letterLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(letterLabel)

        setupScrollView(letterScrollView, textView: letterTextView)
        view.addSubview(letterScrollView)

        letterCICheckbox.translatesAutoresizingMaskIntoConstraints = false
        letterCICheckbox.target = self
        letterCICheckbox.action = #selector(letterCIChanged)
        letterCICheckbox.state = SettingsStore.shared.isLetterCaseInsensitive ? .on : .off
        view.addSubview(letterCICheckbox)
        view.addSubview(letterWarningLabel)

        // Word section
        wordLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(wordLabel)

        setupScrollView(wordScrollView, textView: wordTextView)
        view.addSubview(wordScrollView)

        wordCICheckbox.translatesAutoresizingMaskIntoConstraints = false
        wordCICheckbox.target = self
        wordCICheckbox.action = #selector(wordCIChanged)
        wordCICheckbox.state = SettingsStore.shared.isWordCaseInsensitive ? .on : .off
        view.addSubview(wordCICheckbox)

        // Buttons
        importButton.bezelStyle = .rounded
        importButton.target = self
        importButton.action = #selector(importCSV)
        importButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(importButton)

        exportButton.bezelStyle = .rounded
        exportButton.target = self
        exportButton.action = #selector(exportCSV)
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(exportButton)

        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveRules)
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveButton)

        // Layout
        NSLayoutConstraint.activate([
            // Letter label
            letterLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            letterLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            letterLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // Letter scroll
            letterScrollView.topAnchor.constraint(equalTo: letterLabel.bottomAnchor, constant: 6),
            letterScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            letterScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            letterScrollView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.27),

            // Letter CI checkbox
            letterCICheckbox.topAnchor.constraint(equalTo: letterScrollView.bottomAnchor, constant: 6),
            letterCICheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            // Letter validation warning — same row as CI checkbox, trailing
            letterWarningLabel.centerYAnchor.constraint(equalTo: letterCICheckbox.centerYAnchor),
            letterWarningLabel.leadingAnchor.constraint(equalTo: letterCICheckbox.trailingAnchor, constant: 12),
            letterWarningLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            // Word label
            wordLabel.topAnchor.constraint(equalTo: letterCICheckbox.bottomAnchor, constant: 14),
            wordLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            wordLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // Word scroll
            wordScrollView.topAnchor.constraint(equalTo: wordLabel.bottomAnchor, constant: 6),
            wordScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            wordScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            wordScrollView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.27),

            // Word CI checkbox
            wordCICheckbox.topAnchor.constraint(equalTo: wordScrollView.bottomAnchor, constant: 6),
            wordCICheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            // Import button
            importButton.topAnchor.constraint(equalTo: wordCICheckbox.bottomAnchor, constant: 14),
            importButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            // Export button
            exportButton.topAnchor.constraint(equalTo: wordCICheckbox.bottomAnchor, constant: 14),
            exportButton.leadingAnchor.constraint(equalTo: importButton.trailingAnchor, constant: 8),

            // Save button
            saveButton.topAnchor.constraint(equalTo: wordCICheckbox.bottomAnchor, constant: 14),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            saveButton.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16),
        ])
    }

    private func setupScrollView(_ scrollView: NSScrollView, textView: NSTextView) {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true

        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.delegate = self

        scrollView.documentView = textView
    }

    // MARK: - Load Rules

    private func loadRules() {
        Task {
            let letterRules = await DictionaryStore.shared.allLetterRules()
            let wordRules   = await DictionaryStore.shared.allWordRules()

            letterTextView.string = rulesAsText(letterRules)
            wordTextView.string   = rulesAsText(wordRules)
        }
    }

    private func rulesAsText(_ rules: [String: String]) -> String {
        rules.sorted { $0.key < $1.key }
             .map { "\($0.key),\($0.value)" }
             .joined(separator: "\n")
    }

    // MARK: - Actions

    @objc private func letterCIChanged(_ sender: NSButton) {
        SettingsStore.shared.isLetterCaseInsensitive = sender.state == .on
        log.info("Letter CI: \(sender.state == .on)")
    }

    @objc private func wordCIChanged(_ sender: NSButton) {
        SettingsStore.shared.isWordCaseInsensitive = sender.state == .on
        log.info("Word CI: \(sender.state == .on)")
    }

    @objc private func saveRules() {
        let (letterRules, _) = parseLetterRules(letterTextView.string)
        let wordRules         = parseText(wordTextView.string)

        Task {
            await DictionaryStore.shared.replaceAllLetterRules(letterRules)
            await DictionaryStore.shared.replaceAllWordRules(wordRules)
            log.info("Rules saved: \(letterRules.count) letter, \(wordRules.count) word")
        }
    }

    @objc private func importCSV() {
        Task {
            guard let rules = await CSVService.importRules() else { return }
            await DictionaryStore.shared.replaceAllWordRules(rules)
            // Reload text view
            let updated = await DictionaryStore.shared.allWordRules()
            wordTextView.string = rulesAsText(updated)
            log.info("Imported \(rules.count) word rules via CSV")
        }
    }

    @objc private func exportCSV() {
        Task {
            let rules = await DictionaryStore.shared.allWordRules()
            await CSVService.exportRules(rules)
        }
    }

    // MARK: - Parse

    /// Letter rules: from ve to alanları tam olarak 1 Unicode karakter olmalı.
    /// Geçersiz satırlar atlanır; dönen `invalidCount` ile uyarı label güncellenir.
    private func parseLetterRules(_ text: String) -> (valid: [String: String], invalidCount: Int) {
        var result: [String: String] = [:]
        var invalidCount = 0
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: ",", maxSplits: 1).map { String($0) }
            guard parts.count == 2 else { invalidCount += 1; continue }
            let from = parts[0], to = parts[1]
            guard from.count == 1 && to.count == 1 else { invalidCount += 1; continue }
            result[from] = to
        }
        return (result, invalidCount)
    }

    /// Word rules: from ve to uzunluk kısıtlaması yok.
    private func parseText(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: ",", maxSplits: 1).map { String($0) }
            guard parts.count == 2 else { continue }
            result[parts[0]] = parts[1]
        }
        return result
    }

    /// Letter text view değiştiğinde geçersiz satır sayısını anlık göster.
    private func updateLetterValidation() {
        let (_, invalidCount) = parseLetterRules(letterTextView.string)
        if invalidCount > 0 {
            letterWarningLabel.stringValue = "⚠ \(invalidCount) geçersiz satır atlandı (her alan 1 karakter olmalı)"
            letterWarningLabel.isHidden = false
        } else {
            letterWarningLabel.isHidden = true
        }
    }
}

// MARK: - NSTextViewDelegate (auto-save debounce + letter validation)

extension SettingsViewController: NSTextViewDelegate {
    nonisolated func textViewDidChangeSelection(_ notification: Notification) {
        // Letter textview odaklandığında letter replace bypass'ını aç,
        // word textview veya başka bir alan odaklandığında kapat.
        Task { @MainActor in
            let isLetter = (notification.object as? NSTextView) === self.letterTextView
            SettingsStore.shared.isEditingLetterRulesCached = isLetter
        }
    }

    nonisolated func textDidChange(_ notification: Notification) {
        Task { @MainActor in
            // Letter text view değişiyorsa anlık validasyon göster
            if (notification.object as? NSTextView) === self.letterTextView {
                self.updateLetterValidation()
            }
            self.saveDebounceTask?.cancel()
            self.saveDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                guard !Task.isCancelled else { return }
                self.saveRules()
            }
        }
    }
}
