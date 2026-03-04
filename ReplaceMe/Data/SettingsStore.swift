// SettingsStore.swift — UserDefaults wrapper (thread-safe cached booleans)

import Foundation
import Combine

/// Thread-safe settings store.
/// `*Cached` properties: CGEventTap callback'inde async/await olmadan okunabilir.
final class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    // MARK: - UserDefaults keys

    private enum Keys {
        static let isGlobalActive              = "isGlobalActive"
        static let isLetterReplaceActive       = "isLetterReplaceActive"
        static let isWordReplaceActive         = "isWordReplaceActive"
        static let isLetterCaseInsensitive     = "isLetterCaseInsensitive"
        static let isWordCaseInsensitive       = "isWordCaseInsensitive"
    }

    // MARK: - Published (UI binding)

    @Published var isGlobalActive: Bool {
        didSet {
            UserDefaults.standard.set(isGlobalActive, forKey: Keys.isGlobalActive)
            isGlobalActiveCached = isGlobalActive
        }
    }

    @Published var isLetterReplaceActive: Bool {
        didSet {
            UserDefaults.standard.set(isLetterReplaceActive, forKey: Keys.isLetterReplaceActive)
            isLetterReplaceActiveCached = isLetterReplaceActive
        }
    }

    @Published var isWordReplaceActive: Bool {
        didSet {
            UserDefaults.standard.set(isWordReplaceActive, forKey: Keys.isWordReplaceActive)
            isWordReplaceActiveCached = isWordReplaceActive
        }
    }

    @Published var isLetterCaseInsensitive: Bool {
        didSet {
            UserDefaults.standard.set(isLetterCaseInsensitive, forKey: Keys.isLetterCaseInsensitive)
            isLetterCaseInsensitiveCached = isLetterCaseInsensitive
        }
    }

    @Published var isWordCaseInsensitive: Bool {
        didSet {
            UserDefaults.standard.set(isWordCaseInsensitive, forKey: Keys.isWordCaseInsensitive)
            isWordCaseInsensitiveCached = isWordCaseInsensitive
        }
    }

    // MARK: - Thread-safe cached values (CGEventTap callback için)

    private(set) var isGlobalActiveCached: Bool
    private(set) var isLetterReplaceActiveCached: Bool
    private(set) var isWordReplaceActiveCached: Bool
    private(set) var isLetterCaseInsensitiveCached: Bool
    private(set) var isWordCaseInsensitiveCached: Bool
    /// CGEventTap callback'ten güvenle okunabilir — own-app bypass için
    var isOwnAppFocusedCached: Bool = false

    // MARK: - Init

    private init() {
        // Varsayılan: her şey aktif, CI kapalı
        let defaults = UserDefaults.standard
        let global    = defaults.object(forKey: Keys.isGlobalActive)            .flatMap { $0 as? Bool } ?? true
        let letter    = defaults.object(forKey: Keys.isLetterReplaceActive)     .flatMap { $0 as? Bool } ?? true
        let word      = defaults.object(forKey: Keys.isWordReplaceActive)       .flatMap { $0 as? Bool } ?? true
        let letterCI  = defaults.object(forKey: Keys.isLetterCaseInsensitive)   .flatMap { $0 as? Bool } ?? false
        let wordCI    = defaults.object(forKey: Keys.isWordCaseInsensitive)     .flatMap { $0 as? Bool } ?? false

        isGlobalActive              = global
        isLetterReplaceActive       = letter
        isWordReplaceActive         = word
        isLetterCaseInsensitive     = letterCI
        isWordCaseInsensitive       = wordCI

        isGlobalActiveCached            = global
        isLetterReplaceActiveCached     = letter
        isWordReplaceActiveCached       = word
        isLetterCaseInsensitiveCached   = letterCI
        isWordCaseInsensitiveCached     = wordCI
    }
}
