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
        static let isLetterCapitalReplace      = "isLetterCapitalReplace"
        static let isLetterUppercaseReplace    = "isLetterUppercaseReplace"
        static let isWordCapitalReplace        = "isWordCapitalReplace"
        static let isWordUppercaseReplace      = "isWordUppercaseReplace"
        static let activationShortcut          = "activationShortcut"
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

    @Published var isLetterCapitalReplace: Bool {
        didSet {
            UserDefaults.standard.set(isLetterCapitalReplace, forKey: Keys.isLetterCapitalReplace)
            isLetterCapitalReplaceCached = isLetterCapitalReplace
        }
    }

    @Published var isLetterUppercaseReplace: Bool {
        didSet {
            UserDefaults.standard.set(isLetterUppercaseReplace, forKey: Keys.isLetterUppercaseReplace)
            isLetterUppercaseReplaceCached = isLetterUppercaseReplace
        }
    }

    @Published var isWordCapitalReplace: Bool {
        didSet {
            UserDefaults.standard.set(isWordCapitalReplace, forKey: Keys.isWordCapitalReplace)
            isWordCapitalReplaceCached = isWordCapitalReplace
        }
    }

    @Published var isWordUppercaseReplace: Bool {
        didSet {
            UserDefaults.standard.set(isWordUppercaseReplace, forKey: Keys.isWordUppercaseReplace)
            isWordUppercaseReplaceCached = isWordUppercaseReplace
        }
    }

    /// Global activation/deactivation keyboard shortcut sequence (empty = not configured).
    /// Supports 1–3 sequential strokes (e.g. ⌘K then ⌘S).
    @Published var activationShortcut: [HotkeyCombo] {
        didSet {
            if let data = try? JSONEncoder().encode(activationShortcut) {
                UserDefaults.standard.set(data, forKey: Keys.activationShortcut)
            }
            activationShortcutCached = activationShortcut
        }
    }

    // MARK: - Thread-safe cached values (CGEventTap callback için)

    private(set) var isGlobalActiveCached: Bool
    private(set) var isLetterReplaceActiveCached: Bool
    private(set) var isWordReplaceActiveCached: Bool
    private(set) var isLetterCaseInsensitiveCached: Bool
    private(set) var isWordCaseInsensitiveCached: Bool
    private(set) var isLetterCapitalReplaceCached: Bool
    private(set) var isLetterUppercaseReplaceCached: Bool
    private(set) var isWordCapitalReplaceCached: Bool
    private(set) var isWordUppercaseReplaceCached: Bool
    /// CGEventTap'ten okunabilir — global activation shortcut cache.
    private(set) var activationShortcutCached: [HotkeyCombo]
    /// CGEventTap callback'ten güvenle okunabilir — own-app bypass için
    var isOwnAppFocusedCached: Bool = false
    /// Letter rules textview odakta iken true — letter replace bypass'ı için.
    /// Word replace her zaman çalışır; sadece letter textview'da letter replace bypass edilir.
    var isEditingLetterRulesCached: Bool = false

    // MARK: - Init

    private init() {
        // Varsayılan: her şey aktif, CI ve sub-seçenekler kapalı
        let defaults = UserDefaults.standard
        let global        = defaults.object(forKey: Keys.isGlobalActive)            .flatMap { $0 as? Bool } ?? true
        let letter        = defaults.object(forKey: Keys.isLetterReplaceActive)     .flatMap { $0 as? Bool } ?? true
        let word          = defaults.object(forKey: Keys.isWordReplaceActive)       .flatMap { $0 as? Bool } ?? true
        let letterCI      = defaults.object(forKey: Keys.isLetterCaseInsensitive)   .flatMap { $0 as? Bool } ?? false
        let wordCI        = defaults.object(forKey: Keys.isWordCaseInsensitive)     .flatMap { $0 as? Bool } ?? false
        let letterCap     = defaults.object(forKey: Keys.isLetterCapitalReplace)    .flatMap { $0 as? Bool } ?? false
        let letterUpper   = defaults.object(forKey: Keys.isLetterUppercaseReplace)  .flatMap { $0 as? Bool } ?? false
        let wordCap       = defaults.object(forKey: Keys.isWordCapitalReplace)      .flatMap { $0 as? Bool } ?? false
        let wordUpper     = defaults.object(forKey: Keys.isWordUppercaseReplace)    .flatMap { $0 as? Bool } ?? false

        isGlobalActive              = global
        isLetterReplaceActive       = letter
        isWordReplaceActive         = word
        isLetterCaseInsensitive     = letterCI
        isWordCaseInsensitive       = wordCI
        isLetterCapitalReplace      = letterCap
        isLetterUppercaseReplace    = letterUpper
        isWordCapitalReplace        = wordCap
        isWordUppercaseReplace      = wordUpper

        let shortcut: [HotkeyCombo]
        if let data = defaults.data(forKey: Keys.activationShortcut) {
            // Try new format ([HotkeyCombo]) first, fall back to old single-combo format
            if let arr = try? JSONDecoder().decode([HotkeyCombo].self, from: data) {
                shortcut = arr
            } else if let single = try? JSONDecoder().decode(HotkeyCombo.self, from: data) {
                shortcut = [single]  // migrate old single-combo storage
            } else {
                shortcut = []
            }
        } else {
            shortcut = []
        }
        activationShortcut = shortcut

        isGlobalActiveCached            = global
        isLetterReplaceActiveCached     = letter
        isWordReplaceActiveCached       = word
        isLetterCaseInsensitiveCached   = letterCI
        isWordCaseInsensitiveCached     = wordCI
        isLetterCapitalReplaceCached    = letterCap
        isLetterUppercaseReplaceCached  = letterUpper
        isWordCapitalReplaceCached      = wordCap
        isWordUppercaseReplaceCached    = wordUpper
        activationShortcutCached        = shortcut
    }
}
