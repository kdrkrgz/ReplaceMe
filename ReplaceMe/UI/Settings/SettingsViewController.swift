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
    private let letterCapitalCheckbox  = NSButton(checkboxWithTitle: "Capital Replace Active",  target: nil, action: nil)
    private let letterUppercaseCheckbox = NSButton(checkboxWithTitle: "Uppercase Replace Active", target: nil, action: nil)
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
    private let wordCapitalCheckbox    = NSButton(checkboxWithTitle: "Capital Replace Active",  target: nil, action: nil)
    private let wordUppercaseCheckbox  = NSButton(checkboxWithTitle: "Uppercase Replace Active", target: nil, action: nil)

    private let importButton     = NSButton(title: "Import CSV", target: nil, action: nil)
    private let exportButton     = NSButton(title: "Export CSV", target: nil, action: nil)
    private let saveButton       = NSButton(title: "Save", target: nil, action: nil)

    private var saveDebounceTask: Task<Void, Never>?

    /// İlk odaklanılacak view — SettingsWindowController tarafından first responder yapılır.
    var firstEditableView: NSView { letterTextView }

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 620))
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

        letterCapitalCheckbox.translatesAutoresizingMaskIntoConstraints = false
        letterCapitalCheckbox.target = self
        letterCapitalCheckbox.action = #selector(letterCapitalChanged)
        letterCapitalCheckbox.state = SettingsStore.shared.isLetterCapitalReplace ? .on : .off
        view.addSubview(letterCapitalCheckbox)

        letterUppercaseCheckbox.translatesAutoresizingMaskIntoConstraints = false
        letterUppercaseCheckbox.target = self
        letterUppercaseCheckbox.action = #selector(letterUppercaseChanged)
        letterUppercaseCheckbox.state = SettingsStore.shared.isLetterUppercaseReplace ? .on : .off
        view.addSubview(letterUppercaseCheckbox)

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

        wordCapitalCheckbox.translatesAutoresizingMaskIntoConstraints = false
        wordCapitalCheckbox.target = self
        wordCapitalCheckbox.action = #selector(wordCapitalChanged)
        wordCapitalCheckbox.state = SettingsStore.shared.isWordCapitalReplace ? .on : .off
        view.addSubview(wordCapitalCheckbox)

        wordUppercaseCheckbox.translatesAutoresizingMaskIntoConstraints = false
        wordUppercaseCheckbox.target = self
        wordUppercaseCheckbox.action = #selector(wordUppercaseChanged)
        wordUppercaseCheckbox.state = SettingsStore.shared.isWordUppercaseReplace ? .on : .off
        view.addSubview(wordUppercaseCheckbox)

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

            // Letter scroll — fixed height
            letterScrollView.topAnchor.constraint(equalTo: letterLabel.bottomAnchor, constant: 6),
            letterScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            letterScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            letterScrollView.heightAnchor.constraint(equalToConstant: 140),

            // Letter CI checkbox
            letterCICheckbox.topAnchor.constraint(equalTo: letterScrollView.bottomAnchor, constant: 6),
            letterCICheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            // Letter validation warning — same row as CI checkbox, trailing
            letterWarningLabel.centerYAnchor.constraint(equalTo: letterCICheckbox.centerYAnchor),
            letterWarningLabel.leadingAnchor.constraint(equalTo: letterCICheckbox.trailingAnchor, constant: 12),
            letterWarningLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            // Letter sub-checkboxes — indented, side by side
            letterCapitalCheckbox.topAnchor.constraint(equalTo: letterCICheckbox.bottomAnchor, constant: 4),
            letterCapitalCheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            letterUppercaseCheckbox.centerYAnchor.constraint(equalTo: letterCapitalCheckbox.centerYAnchor),
            letterUppercaseCheckbox.leadingAnchor.constraint(equalTo: letterCapitalCheckbox.trailingAnchor, constant: 16),

            // Word label
            wordLabel.topAnchor.constraint(equalTo: letterCapitalCheckbox.bottomAnchor, constant: 10),
            wordLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            wordLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // Word scroll — fixed height
            wordScrollView.topAnchor.constraint(equalTo: wordLabel.bottomAnchor, constant: 6),
            wordScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            wordScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            wordScrollView.heightAnchor.constraint(equalToConstant: 140),

            // Word CI checkbox
            wordCICheckbox.topAnchor.constraint(equalTo: wordScrollView.bottomAnchor, constant: 6),
            wordCICheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            // Word sub-checkboxes — indented, side by side
            wordCapitalCheckbox.topAnchor.constraint(equalTo: wordCICheckbox.bottomAnchor, constant: 4),
            wordCapitalCheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            wordUppercaseCheckbox.centerYAnchor.constraint(equalTo: wordCapitalCheckbox.centerYAnchor),
            wordUppercaseCheckbox.leadingAnchor.constraint(equalTo: wordCapitalCheckbox.trailingAnchor, constant: 16),

            // Import button
            importButton.topAnchor.constraint(equalTo: wordCapitalCheckbox.bottomAnchor, constant: 14),
            importButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            // Export button
            exportButton.topAnchor.constraint(equalTo: wordCapitalCheckbox.bottomAnchor, constant: 14),
            exportButton.leadingAnchor.constraint(equalTo: importButton.trailingAnchor, constant: 8),

            // Save button
            saveButton.topAnchor.constraint(equalTo: wordCapitalCheckbox.bottomAnchor, constant: 14),
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
        // Cmd+F ile inline find bar — NSTextFinder dispatch'i mainMenu üzerinden gelir
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        scrollView.documentView = textView
    }

    // MARK: - Load Rules

    private func loadRules() {
        Task {
            let letterRules = await DictionaryStore.shared.allLetterRules()
            let wordRules   = await DictionaryStore.shared.allWordRules()

            letterTextView.string = rulesAsText(letterRules)
            wordTextView.string   = rulesAsText(wordRules)

            // Son eklenen kuralı görmek için her iki text view'ı en alta kaydır
            letterTextView.scrollToEndOfDocument(nil)
            wordTextView.scrollToEndOfDocument(nil)
        }
    }

    private func rulesAsText(_ rules: [String: String]) -> String {
        rules.sorted { $0.key < $1.key }
             .map { "\($0.key),\($0.value)" }
             .joined(separator: "\n")
    }

    // MARK: - Actions

    @objc private func letterCIChanged(_ sender: NSButton) {
        let isOn = sender.state == .on
        SettingsStore.shared.isLetterCaseInsensitive = isOn
        if isOn {
            // CI açıldığında her ikisini de otomatik aç
            SettingsStore.shared.isLetterCapitalReplace = true
            SettingsStore.shared.isLetterUppercaseReplace = true
            letterCapitalCheckbox.state = .on
            letterUppercaseCheckbox.state = .on
        } else {
            // CI kapatıldığında her ikisini de otomatik kapat
            // CI=ON geçerli tek hal her ikisinin de açık olmasını gerektirir
            SettingsStore.shared.isLetterCapitalReplace = false
            SettingsStore.shared.isLetterUppercaseReplace = false
            letterCapitalCheckbox.state = .off
            letterUppercaseCheckbox.state = .off
        }
        log.info("Letter CI: \(isOn)")
    }

    @objc private func letterCapitalChanged(_ sender: NSButton) {
        let isOn = sender.state == .on
        SettingsStore.shared.isLetterCapitalReplace = isOn
        if isOn && SettingsStore.shared.isLetterUppercaseReplace {
            // Her ikisi de açık → CI'yi otomatik aç
            SettingsStore.shared.isLetterCaseInsensitive = true
            letterCICheckbox.state = .on
        } else if !isOn {
            // Capital kapandı → CI kapat
            SettingsStore.shared.isLetterCaseInsensitive = false
            letterCICheckbox.state = .off
        }
    }

    @objc private func letterUppercaseChanged(_ sender: NSButton) {
        let isOn = sender.state == .on
        SettingsStore.shared.isLetterUppercaseReplace = isOn
        if isOn && SettingsStore.shared.isLetterCapitalReplace {
            // Her ikisi de açık → CI'yi otomatik aç
            SettingsStore.shared.isLetterCaseInsensitive = true
            letterCICheckbox.state = .on
        } else if !isOn {
            // Uppercase kapandı → CI kapat
            SettingsStore.shared.isLetterCaseInsensitive = false
            letterCICheckbox.state = .off
        }
    }

    @objc private func wordCIChanged(_ sender: NSButton) {
        let isOn = sender.state == .on
        SettingsStore.shared.isWordCaseInsensitive = isOn
        if isOn {
            SettingsStore.shared.isWordCapitalReplace = true
            SettingsStore.shared.isWordUppercaseReplace = true
            wordCapitalCheckbox.state = .on
            wordUppercaseCheckbox.state = .on
        } else {
            // CI kapatıldığında her ikisini de otomatik kapat
            SettingsStore.shared.isWordCapitalReplace = false
            SettingsStore.shared.isWordUppercaseReplace = false
            wordCapitalCheckbox.state = .off
            wordUppercaseCheckbox.state = .off
        }
        log.info("Word CI: \(isOn)")
    }

    @objc private func wordCapitalChanged(_ sender: NSButton) {
        let isOn = sender.state == .on
        SettingsStore.shared.isWordCapitalReplace = isOn
        if isOn && SettingsStore.shared.isWordUppercaseReplace {
            SettingsStore.shared.isWordCaseInsensitive = true
            wordCICheckbox.state = .on
        } else if !isOn {
            SettingsStore.shared.isWordCaseInsensitive = false
            wordCICheckbox.state = .off
        }
    }

    @objc private func wordUppercaseChanged(_ sender: NSButton) {
        let isOn = sender.state == .on
        SettingsStore.shared.isWordUppercaseReplace = isOn
        if isOn && SettingsStore.shared.isWordCapitalReplace {
            SettingsStore.shared.isWordCaseInsensitive = true
            wordCICheckbox.state = .on
        } else if !isOn {
            SettingsStore.shared.isWordCaseInsensitive = false
            wordCICheckbox.state = .off
        }
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
            // Reload text view ve en alta kaydır
            let updated = await DictionaryStore.shared.allWordRules()
            wordTextView.string = rulesAsText(updated)
            wordTextView.scrollToEndOfDocument(nil)
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
