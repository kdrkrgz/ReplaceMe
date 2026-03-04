// DictionaryData.swift — Codable JSON schema

/// JSON schema version — migration için kullanılır.
struct DictionaryData: Codable {
    var version: Int = 1
    var letterRules: [RuleEntry] = []
    var wordRules: [RuleEntry] = []

    struct RuleEntry: Codable, Equatable {
        var from: String
        var to: String
    }
}

/// Thread-safe read-only snapshot — CGEventTap callback'inde kullanılır.
struct DictionarySnapshot {
    let letterRules: [String: String]  // from → to
    let wordRules: [String: String]    // from → to

    static let empty = DictionarySnapshot(letterRules: [:], wordRules: [:])
}
