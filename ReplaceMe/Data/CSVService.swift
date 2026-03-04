// CSVService.swift — CSV import/export (word replace kuralları için)

import AppKit
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "CSVService")

enum CSVService {

    // MARK: - Parse / Serialize

    /// "kelime,replace\nkelime2,replace2" → [from: to]
    static func parse(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: ",", maxSplits: 1).map { String($0) }
            guard parts.count == 2 else {
                log.warning("Skipping malformed CSV line: \(trimmed)")
                continue
            }
            result[parts[0]] = parts[1]
        }
        return result
    }

    /// [from: to] → "kelime,replace\n..."
    static func serialize(_ rules: [String: String]) -> String {
        rules
            .sorted { $0.key < $1.key }
            .map { "\($0.key),\($0.value)" }
            .joined(separator: "\n")
    }

    // MARK: - Import / Export (main thread UI operations)

    @MainActor
    static func importRules() async -> [String: String]? {
        let panel = NSOpenPanel()
        panel.title = "Import Word Replace Rules"
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard await panel.beginSheetModal(for: NSApp.keyWindow ?? NSApp.mainWindow ?? NSWindow()) == .OK,
              let url = panel.url else {
            return nil
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rules = parse(content)
            log.info("Imported \(rules.count) rules from \(url.lastPathComponent)")
            return rules
        } catch {
            log.error("Import failed: \(error.localizedDescription)")
            showError("Could not read file: \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    static func exportRules(_ rules: [String: String]) async {
        let panel = NSSavePanel()
        panel.title = "Export Word Replace Rules"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "rm-word-rules.csv"

        guard await panel.beginSheetModal(for: NSApp.keyWindow ?? NSApp.mainWindow ?? NSWindow()) == .OK,
              let url = panel.url else { return }

        let content = serialize(rules)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            log.info("Exported \(rules.count) rules to \(url.lastPathComponent)")
        } catch {
            log.error("Export failed: \(error.localizedDescription)")
            showError("Could not write file: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private static func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "CSV Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
