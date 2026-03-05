// DictionaryData.swift — Codable JSON schema

import Foundation

/// JSON schema version — migration için kullanılır.
struct DictionaryData: Codable {
    var version: Int = 1
    var letterRules: [RuleEntry] = []
    var wordRules: [RuleEntry] = []
    var urlSources: [URLSource] = []

    struct RuleEntry: Codable, Equatable {
        var from: String
        var to: String
    }
}

/// Kaydedilmiş URL veri kaynağı — kelime kurallarını uzak URL'den çeker.
struct URLSource: Codable, Equatable, Identifiable {
    var id: String
    var url: String
    var lastFetched: Date?
    var ruleCount: Int = 0
    var lastError: String?

    init(url: String) {
        self.id = UUID().uuidString
        self.url = url
    }
}

/// Thread-safe read-only snapshot — CGEventTap callback'inde kullanılır.
struct DictionarySnapshot {
    let letterRules: [String: String]    // from → to (exact)
    let wordRules: [String: String]      // from → to (exact)
    let ciLetterRules: [String: String]  // lowercased(from) → to (case-insensitive lookup için)
    let ciWordRules: [String: String]    // lowercased(from) → to (case-insensitive lookup için)

    static let empty = DictionarySnapshot(
        letterRules: [:], wordRules: [:],
        ciLetterRules: [:], ciWordRules: [:]
    )
}
