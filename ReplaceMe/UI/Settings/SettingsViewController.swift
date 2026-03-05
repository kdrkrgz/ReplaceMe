// SettingsViewController.swift — Letter + Word replace kural editörü

import AppKit
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "Settings")

/// objc_setAssociatedObject key — pointer identity ile çalışır, string literal güvenilmez.
private var urlSourceIdKey: UInt8 = 0

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
    private let wordWarningLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = NSColor.systemRed
        label.isHidden = true
        return label
    }()
    private let wordCICheckbox   = NSButton(checkboxWithTitle: "Case Insensitive", target: nil, action: nil)
    private let wordCapitalCheckbox    = NSButton(checkboxWithTitle: "Capital Replace Active",  target: nil, action: nil)
    private let wordUppercaseCheckbox  = NSButton(checkboxWithTitle: "Uppercase Replace Active", target: nil, action: nil)

    private let importButton     = NSButton(title: "Import CSV", target: nil, action: nil)
    private let exportButton     = NSButton(title: "Export CSV", target: nil, action: nil)
    private let importURLButton  = NSButton(title: "Import URL", target: nil, action: nil)
    private let saveButton       = NSButton(title: "Save", target: nil, action: nil)

    // URL Sources section
    private let urlSourcesLabel  = NSTextField(labelWithString: "URL Sources")
    private let urlSourcesScrollView = NSScrollView()
    private let urlSourcesStackView  = NSStackView()

    private var saveDebounceTask: Task<Void, Never>?
    private var wordValidationTask: Task<Void, Never>?
    /// Validation'dan gelen geçersiz satır range'leri — click ile navigate edilir.
    private var wordInvalidLineRanges: [NSRange] = []
    /// Bir sonraki tıklamada gidilecek index (0-based, cycling).
    private var wordValidationCurrentErrorIndex: Int = 0

    /// İlk odaklanılacak view — SettingsWindowController tarafından first responder yapılır.
    var firstEditableView: NSView { letterTextView }

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 700))
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
        view.addSubview(wordWarningLabel)
        wordWarningLabel.addGestureRecognizer(
            NSClickGestureRecognizer(target: self, action: #selector(navigateToNextWordError))
        )

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

        importURLButton.bezelStyle = .rounded
        importURLButton.target = self
        importURLButton.action = #selector(importURLTapped)
        importURLButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(importURLButton)

        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveRules)
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveButton)

        // URL Sources section
        urlSourcesLabel.translatesAutoresizingMaskIntoConstraints = false
        urlSourcesLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        urlSourcesLabel.textColor = .secondaryLabelColor
        view.addSubview(urlSourcesLabel)

        urlSourcesScrollView.translatesAutoresizingMaskIntoConstraints = false
        urlSourcesScrollView.hasVerticalScroller = true
        urlSourcesScrollView.hasHorizontalScroller = false
        urlSourcesScrollView.borderType = .bezelBorder
        urlSourcesScrollView.autohidesScrollers = true

        urlSourcesStackView.orientation = .vertical
        urlSourcesStackView.alignment = .leading
        urlSourcesStackView.spacing = 4
        urlSourcesStackView.translatesAutoresizingMaskIntoConstraints = false
        urlSourcesStackView.setHuggingPriority(.defaultHigh, for: .vertical)

        let clipView = NSClipView()
        clipView.documentView = urlSourcesStackView
        urlSourcesScrollView.contentView = clipView
        view.addSubview(urlSourcesScrollView)

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

            // Word validation warning — same row as CI checkbox, trailing
            wordWarningLabel.centerYAnchor.constraint(equalTo: wordCICheckbox.centerYAnchor),
            wordWarningLabel.leadingAnchor.constraint(equalTo: wordCICheckbox.trailingAnchor, constant: 12),
            wordWarningLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            // Word sub-checkboxes — indented, side by side
            wordCapitalCheckbox.topAnchor.constraint(equalTo: wordCICheckbox.bottomAnchor, constant: 4),
            wordCapitalCheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            wordUppercaseCheckbox.centerYAnchor.constraint(equalTo: wordCapitalCheckbox.centerYAnchor),
            wordUppercaseCheckbox.leadingAnchor.constraint(equalTo: wordCapitalCheckbox.trailingAnchor, constant: 16),

            // Import CSV
            importButton.topAnchor.constraint(equalTo: wordCapitalCheckbox.bottomAnchor, constant: 14),
            importButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            // Export CSV
            exportButton.topAnchor.constraint(equalTo: wordCapitalCheckbox.bottomAnchor, constant: 14),
            exportButton.leadingAnchor.constraint(equalTo: importButton.trailingAnchor, constant: 8),

            // Import URL
            importURLButton.topAnchor.constraint(equalTo: wordCapitalCheckbox.bottomAnchor, constant: 14),
            importURLButton.leadingAnchor.constraint(equalTo: exportButton.trailingAnchor, constant: 8),

            // Save button
            saveButton.topAnchor.constraint(equalTo: wordCapitalCheckbox.bottomAnchor, constant: 14),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // URL Sources label
            urlSourcesLabel.topAnchor.constraint(equalTo: importButton.bottomAnchor, constant: 14),
            urlSourcesLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            // URL Sources scroll view
            urlSourcesScrollView.topAnchor.constraint(equalTo: urlSourcesLabel.bottomAnchor, constant: 4),
            urlSourcesScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            urlSourcesScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            urlSourcesScrollView.heightAnchor.constraint(equalToConstant: 80),
            urlSourcesScrollView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16),

            // Stack view inside scroll view
            urlSourcesStackView.topAnchor.constraint(equalTo: urlSourcesScrollView.contentView.topAnchor),
            urlSourcesStackView.leadingAnchor.constraint(equalTo: urlSourcesScrollView.contentView.leadingAnchor, constant: 4),
            urlSourcesStackView.trailingAnchor.constraint(equalTo: urlSourcesScrollView.contentView.trailingAnchor, constant: -4),
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

            // URL sources listesini yükle
            reloadURLSourcesList()
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

    // MARK: - URL Import

    private static let urlMarkerStart = "# ── 📡"
    private static let urlMarkerEnd   = "# ── 📡 END ──"

    @objc private func importURLTapped() {
        let alert = NSAlert()
        alert.messageText = "Import URL"
        alert.informativeText = "CSV formatında word replace kuralları içeren URL'yi girin (from,to per line):"
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 24))
        input.placeholderString = "https://example.com/rules.csv"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let urlString = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else { return }

        Task {
            await performURLImport(urlString: urlString)
        }
    }

    private func performURLImport(urlString: String) async {
        // Duplicate check
        let existingSources = await DictionaryStore.shared.allURLSources()
        if existingSources.contains(where: { $0.url == urlString }) {
            let alert = NSAlert()
            alert.messageText = "Duplicate URL"
            alert.informativeText = "Bu URL zaten eklenmiş: \(urlString)"
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        do {
            let rules = try await URLImportService.fetchRules(from: urlString)
            let rulesText = rules
                .sorted { $0.key < $1.key }
                .map { "\($0.key),\($0.value)" }
                .joined(separator: "\n")

            // Text view'a marker'lı ekle
            let markerBlock = "\(Self.urlMarkerStart) \(urlString) ──\n\(rulesText)\n\(Self.urlMarkerEnd)"
            let current = wordTextView.string
            wordTextView.string = current.isEmpty ? markerBlock : current + "\n" + markerBlock
            wordTextView.scrollToEndOfDocument(nil)

            // URL source'u persist et
            var source = URLSource(url: urlString)
            source.lastFetched = Date()
            source.ruleCount = rules.count
            await DictionaryStore.shared.addURLSource(source)

            // Save rules (text view'daki tüm kuralları kaydet)
            saveRules()
            reloadURLSourcesList()

            log.info("URL imported: \(urlString) (\(rules.count) rules)")
        } catch {
            let nsError = error as? URLImportError
            let alert = NSAlert()
            alert.messageText = "URL Import Hatası"
            alert.informativeText = nsError?.errorDescription ?? error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
            log.error("URL import failed: \(error.localizedDescription)")
        }
    }

    private func refreshURLSource(_ source: URLSource) {
        Task {
            do {
                let rules = try await URLImportService.fetchRules(from: source.url)
                let rulesText = rules
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key),\($0.value)" }
                    .joined(separator: "\n")

                // Text view'daki eski marker bölümünü bul ve değiştir
                let text = wordTextView.string
                let markerStart = "\(Self.urlMarkerStart) \(source.url) ──"
                if let startRange = text.range(of: markerStart),
                   let endRange = text.range(of: Self.urlMarkerEnd, range: startRange.upperBound..<text.endIndex) {
                    let fullRange = startRange.lowerBound..<endRange.upperBound
                    let newBlock = "\(markerStart)\n\(rulesText)\n\(Self.urlMarkerEnd)"
                    wordTextView.string = text.replacingCharacters(in: fullRange, with: newBlock)
                } else {
                    // Marker bulunamadı — sonuna ekle
                    let markerBlock = "\(markerStart)\n\(rulesText)\n\(Self.urlMarkerEnd)"
                    let current = wordTextView.string
                    wordTextView.string = current.isEmpty ? markerBlock : current + "\n" + markerBlock
                }

                // Source'u güncelle
                var updated = source
                updated.lastFetched = Date()
                updated.ruleCount = rules.count
                updated.lastError = nil
                await DictionaryStore.shared.updateURLSource(updated)

                saveRules()
                reloadURLSourcesList()
                log.info("URL refreshed: \(source.url) (\(rules.count) rules)")
            } catch {
                var updated = source
                updated.lastError = (error as? URLImportError)?.errorDescription ?? error.localizedDescription
                await DictionaryStore.shared.updateURLSource(updated)
                reloadURLSourcesList()

                let alert = NSAlert()
                alert.messageText = "Refresh Hatası"
                alert.informativeText = "\(source.url)\n\n\(updated.lastError ?? error.localizedDescription)"
                alert.alertStyle = .warning
                alert.runModal()
                log.error("URL refresh failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteURLSource(_ source: URLSource) {
        // Text view'dan marker bölümünü kaldır
        var text = wordTextView.string
        let markerStart = "\(Self.urlMarkerStart) \(source.url) ──"
        if let startRange = text.range(of: markerStart),
           let endRange = text.range(of: Self.urlMarkerEnd, range: startRange.upperBound..<text.endIndex) {
            var removeStart = startRange.lowerBound
            var removeEnd = endRange.upperBound

            // Öncesindeki \n varsa onu da sil
            if removeStart > text.startIndex {
                let before = text.index(before: removeStart)
                if text[before] == "\n" {
                    removeStart = before
                }
            }
            // Sonrasındaki \n varsa onu da sil (arka arkaya boş satır bırakma)
            if removeEnd < text.endIndex && text[removeEnd] == "\n" {
                removeEnd = text.index(after: removeEnd)
            }

            text.removeSubrange(removeStart..<removeEnd)
            wordTextView.string = text
        }

        Task {
            await DictionaryStore.shared.removeURLSource(id: source.id)
            saveRules()
            reloadURLSourcesList()
            log.info("URL source deleted: \(source.url)")
        }
    }

    // MARK: - URL Sources List

    private func reloadURLSourcesList() {
        Task {
            let sources = await DictionaryStore.shared.allURLSources()

            // Stack view'ı temizle
            urlSourcesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

            if sources.isEmpty {
                let emptyLabel = NSTextField(labelWithString: "Henüz URL kaynağı eklenmedi.")
                emptyLabel.font = NSFont.systemFont(ofSize: 11)
                emptyLabel.textColor = .tertiaryLabelColor
                urlSourcesStackView.addArrangedSubview(emptyLabel)
                return
            }

            for source in sources {
                let row = buildURLSourceRow(source)
                urlSourcesStackView.addArrangedSubview(row)
            }
        }
    }

    private func buildURLSourceRow(_ source: URLSource) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 6
        row.alignment = .centerY

        // URL label
        let urlLabel = NSTextField(labelWithString: source.url)
        urlLabel.font = NSFont.systemFont(ofSize: 11)
        urlLabel.lineBreakMode = .byTruncatingMiddle
        urlLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Rule count
        let countLabel = NSTextField(labelWithString: "\(source.ruleCount) kural")
        countLabel.font = NSFont.systemFont(ofSize: 10)
        countLabel.textColor = .secondaryLabelColor
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Error indicator
        if let error = source.lastError {
            urlLabel.textColor = .systemRed
            urlLabel.toolTip = error
        }

        // Refresh button
        let refreshButton = NSButton(title: "↻", target: nil, action: nil)
        refreshButton.bezelStyle = .inline
        refreshButton.font = NSFont.systemFont(ofSize: 12)
        refreshButton.isBordered = false
        refreshButton.toolTip = "Yenile"
        refreshButton.target = self
        let refreshAction = #selector(refreshURLSourceAction(_:))
        refreshButton.action = refreshAction
        refreshButton.tag = source.url.hashValue
        objc_setAssociatedObject(refreshButton, &urlSourceIdKey, source.id, .OBJC_ASSOCIATION_COPY_NONATOMIC)

        // Delete button
        let deleteButton = NSButton(title: "✕", target: nil, action: nil)
        deleteButton.bezelStyle = .inline
        deleteButton.font = NSFont.systemFont(ofSize: 12)
        deleteButton.isBordered = false
        deleteButton.toolTip = "Kaldır"
        deleteButton.target = self
        deleteButton.action = #selector(deleteURLSourceAction(_:))
        objc_setAssociatedObject(deleteButton, &urlSourceIdKey, source.id, .OBJC_ASSOCIATION_COPY_NONATOMIC)

        row.addArrangedSubview(urlLabel)
        row.addArrangedSubview(countLabel)
        row.addArrangedSubview(refreshButton)
        row.addArrangedSubview(deleteButton)

        return row
    }

    @objc private func refreshURLSourceAction(_ sender: NSButton) {
        guard let sourceId = objc_getAssociatedObject(sender, &urlSourceIdKey) as? String else { return }
        Task {
            let sources = await DictionaryStore.shared.allURLSources()
            guard let source = sources.first(where: { $0.id == sourceId }) else { return }
            refreshURLSource(source)
        }
    }

    @objc private func deleteURLSourceAction(_ sender: NSButton) {
        guard let sourceId = objc_getAssociatedObject(sender, &urlSourceIdKey) as? String else { return }
        Task {
            let sources = await DictionaryStore.shared.allURLSources()
            guard let source = sources.first(where: { $0.id == sourceId }) else { return }
            deleteURLSource(source)
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

    /// Word rules: from ve to uzunluk kısıtlaması yok. # ile başlayan yorum satırları atlanır.
    private func parseText(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard !trimmed.hasPrefix("#") else { continue }
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

    /// Tek bir word satırının geçerliliğini kontrol eder.
    /// Geçerli format: `from,to` — tam olarak 1 virgül, her iki taraf trimlenmiş ve dolu olmalı.
    /// `#` ile başlayan yorum satırları her zaman geçerlidir.
    private func validateWordLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        // Yorum satırı — her zaman geçerli
        guard !trimmed.hasPrefix("#") else { return true }
        // Tam olarak 1 virgül olmalı (0 veya 2+ → geçersiz)
        let commaCount = line.filter { $0 == "," }.count
        guard commaCount == 1 else { return false }
        let parts = line.split(separator: ",", maxSplits: 1).map { String($0) }
        guard parts.count == 2 else { return false }
        let from = parts[0], to = parts[1]
        // Boş olmamalı
        guard !from.trimmingCharacters(in: .whitespaces).isEmpty,
              !to.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        // Trimlenmiş olmalı (başında/sonunda boşluk olmamalı)
        guard from == from.trimmingCharacters(in: .whitespaces),
              to == to.trimmingCharacters(in: .whitespaces) else { return false }
        return true
    }

    /// Word text view değiştiğinde geçersiz satırları kırmızıyla işaretle.
    /// NSLayoutManager.addTemporaryAttributes kullanır — textStorage'a dokunmaz,
    /// processEditing tetiklemez, scroll/cursor yan etkisi yoktur.
    private func updateWordValidation() {
        let text = wordTextView.string
        let lines = text.components(separatedBy: "\n")
        guard let layoutManager = wordTextView.layoutManager else { return }

        // Önceki tüm geçici renk işaretlemelerini temizle
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        if fullRange.length > 0 {
            layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullRange)
        }

        var invalidRanges: [NSRange] = []
        var location = 0
        for line in lines {
            let lineLength = (line as NSString).length
            if lineLength > 0 && !validateWordLine(line) {
                let range = NSRange(location: location, length: lineLength)
                layoutManager.addTemporaryAttributes(
                    [.foregroundColor: NSColor.systemRed],
                    forCharacterRange: range
                )
                invalidRanges.append(range)
            }
            location += lineLength + 1 // +1 satır sonu için
        }

        // Yeni validation sonuçlarını sakla ve index'i sıfırla
        wordInvalidLineRanges = invalidRanges
        wordValidationCurrentErrorIndex = 0

        if !invalidRanges.isEmpty {
            wordWarningLabel.stringValue = "⚠ \(invalidRanges.count) geçersiz satır · tıkla: sonraki hata ↩"
            wordWarningLabel.isHidden = false
        } else {
            wordWarningLabel.isHidden = true
        }
    }

    /// Warning label'a her tıklamada sıradaki geçersiz satıra git (cycling).
    @objc private func navigateToNextWordError() {
        guard !wordInvalidLineRanges.isEmpty else { return }
        let range = wordInvalidLineRanges[wordValidationCurrentErrorIndex]
        let oneBasedCurrent = wordValidationCurrentErrorIndex + 1

        // İmleci satırın başına taşı ve scroll et
        wordTextView.setSelectedRange(NSRange(location: range.location, length: 0))
        wordTextView.scrollRangeToVisible(range)
        view.window?.makeFirstResponder(wordTextView)

        // Label'ı mevcut pozisyonla güncelle
        wordWarningLabel.stringValue = "⚠ \(wordInvalidLineRanges.count) geçersiz satır · \(oneBasedCurrent)/\(wordInvalidLineRanges.count) ↩"

        // Bir sonraki tıklama için index'i ilerlet (wrap)
        wordValidationCurrentErrorIndex = (wordValidationCurrentErrorIndex + 1) % wordInvalidLineRanges.count
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
            // Anlık validasyon göster
            if (notification.object as? NSTextView) === self.letterTextView {
                self.updateLetterValidation()
            } else if (notification.object as? NSTextView) === self.wordTextView {
                // Word validasyonu 2 saniye debounce ile çalışır — scroll jump'ı minimize eder
                self.wordValidationTask?.cancel()
                self.wordValidationTask = Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
                    guard !Task.isCancelled else { return }
                    self.updateWordValidation()
                }
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
