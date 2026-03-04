// DictionaryStore.swift — JSON persistence actor (thread-safe, debounced save)

import Foundation
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "DictionaryStore")

// MARK: - Thread-safe snapshot holder (lock-protected, accessible from CGEventTap callback)

private final class SnapshotHolder {
    private let lock = NSLock()
    private var _value: DictionarySnapshot = .empty

    var value: DictionarySnapshot {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}

// MARK: - DictionaryStore Actor

actor DictionaryStore {

    static let shared = DictionaryStore()

    // MARK: - State

    private var letterRules: [String: String] = [:]
    private var wordRules: [String: String] = [:]

    /// Thread-safe snapshot — CGEventTap callback'ten okunabilir (nonisolated, lock-protected).
    private nonisolated let snapshotHolder = SnapshotHolder()

    /// Snapshot read accessor — CGEventTap callback için.
    nonisolated var cachedSnapshot: DictionarySnapshot { snapshotHolder.value }

    private var saveTask: Task<Void, Never>?

    // MARK: - Persistence URL

    private static var fileURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let rmDir = appSupport.appendingPathComponent("RM", isDirectory: true)
        return rmDir.appendingPathComponent("dictionaries.json")
    }

    // MARK: - Load / Save

    func load() throws {
        let url = Self.fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            log.info("No dictionaries.json found — starting fresh")
            return
        }
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(DictionaryData.self, from: data)
        applyData(decoded)
        log.info("Loaded \(self.letterRules.count) letter rules, \(self.wordRules.count) word rules")
    }

    func save() throws {
        let url = Self.fileURL
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var data = DictionaryData()
        data.letterRules = letterRules.map { DictionaryData.RuleEntry(from: $0.key, to: $0.value) }
        data.wordRules   = wordRules.map   { DictionaryData.RuleEntry(from: $0.key, to: $0.value) }

        let encoded = try JSONEncoder().encode(data)
        // Atomic write — dosya bozulmasını önler
        try encoded.write(to: url, options: .atomic)
        log.debug("Saved dictionaries to disk")
    }

    /// 500ms debounce ile kaydet — hızlı ardışık değişimlerde disk thrash önlenir.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            guard !Task.isCancelled else { return }
            do {
                try self.save()
            } catch {
                log.error("Save failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - CRUD

    func setLetterRule(from: String, to: String) {
        letterRules[from] = to
        updateSnapshot()
        scheduleSave()
    }

    func setWordRule(from: String, to: String) {
        wordRules[from] = to
        updateSnapshot()
        scheduleSave()
    }

    func removeLetterRule(from: String) {
        letterRules.removeValue(forKey: from)
        updateSnapshot()
        scheduleSave()
    }

    func removeWordRule(from: String) {
        wordRules.removeValue(forKey: from)
        updateSnapshot()
        scheduleSave()
    }

    func replaceAllLetterRules(_ rules: [String: String]) {
        letterRules = rules
        updateSnapshot()
        scheduleSave()
    }

    func replaceAllWordRules(_ rules: [String: String]) {
        wordRules = rules
        updateSnapshot()
        scheduleSave()
    }

    // MARK: - Lookups (actor context)

    func letterReplacement(for char: Character) -> String? {
        letterRules[String(char)]
    }

    func wordReplacement(for word: String) -> String? {
        wordRules[word]
    }

    // MARK: - Snapshot helpers

    func allLetterRules() -> [String: String] { letterRules }
    func allWordRules() -> [String: String] { wordRules }

    // MARK: - Private

    private func applyData(_ data: DictionaryData) {
        letterRules = Dictionary(uniqueKeysWithValues: data.letterRules.map { ($0.from, $0.to) })
        wordRules   = Dictionary(uniqueKeysWithValues: data.wordRules.map   { ($0.from, $0.to) })
        updateSnapshot()
    }

    private func updateSnapshot() {
        snapshotHolder.value = DictionarySnapshot(letterRules: letterRules, wordRules: wordRules)
    }
}
