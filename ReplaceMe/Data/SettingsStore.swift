// SettingsStore.swift — UserDefaults wrapper (thread-safe cached booleans)

import Foundation
import Combine

/// Thread-safe settings store.
/// `*Cached` properties: CGEventTap callback'inde async/await olmadan okunabilir.
final class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    // MARK: - UserDefaults keys

    private enum Keys {
        static let isGlobalActive        = "isGlobalActive"
        static let isLetterReplaceActive = "isLetterReplaceActive"
        static let isWordReplaceActive   = "isWordReplaceActive"
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

    // MARK: - Thread-safe cached values (CGEventTap callback için)

    private(set) var isGlobalActiveCached: Bool
    private(set) var isLetterReplaceActiveCached: Bool
    private(set) var isWordReplaceActiveCached: Bool

    // MARK: - Init

    private init() {
        // Varsayılan: her şey aktif
        let defaults = UserDefaults.standard
        let global  = defaults.object(forKey: Keys.isGlobalActive)        .flatMap { $0 as? Bool } ?? true
        let letter  = defaults.object(forKey: Keys.isLetterReplaceActive) .flatMap { $0 as? Bool } ?? true
        let word    = defaults.object(forKey: Keys.isWordReplaceActive)   .flatMap { $0 as? Bool } ?? true

        isGlobalActive              = global
        isLetterReplaceActive       = letter
        isWordReplaceActive         = word

        isGlobalActiveCached        = global
        isLetterReplaceActiveCached = letter
        isWordReplaceActiveCached   = word
    }
}
