// ReplaceEngine.swift — Letter replace + word replace iş mantığı (actor isolation)

import Foundation
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "ReplaceEngine")

/// Word terminator key codes (macOS virtual keys)
private enum KeyCode {
    static let space: Int64     = 49
    static let `return`: Int64  = 36
    static let escape: Int64    = 53
    static let delete: Int64    = 51 // Backspace
}

/// Word terminator karakterler (noktalama)
private let wordTerminatorChars: Set<Character> = [".", ",", "!", "?", ";", ":", " "]

private func isWordTerminator(character: Character, keyCode: Int64) -> Bool {
    keyCode == KeyCode.space || keyCode == KeyCode.return || wordTerminatorChars.contains(character)
}

// MARK: - Synchronous state (lock-protected, nonisolated — CGEventTap callback için)

/// CGEventTap callback'i async kullanamaz. Bu sınıf actor dışında, NSLock ile korunan
/// senkron replace state'i tutar.
private final class SynchronousReplaceState {
    private let lock = NSLock()
    private var buffer = WordBuffer()

    func process(character: Character, keyCode: Int64) -> ReplaceAction {
        lock.withLock {
            let snapshot     = DictionaryStore.shared.cachedSnapshot
            let letterActive = SettingsStore.shared.isLetterReplaceActiveCached
            let wordActive   = SettingsStore.shared.isWordReplaceActiveCached
            let letterCI     = SettingsStore.shared.isLetterCaseInsensitiveCached
            let wordCI       = SettingsStore.shared.isWordCaseInsensitiveCached

            // Escape → temizle
            if keyCode == KeyCode.escape {
                buffer.clear()
                return .passthrough
            }

            // Backspace → son karakteri sil
            if keyCode == KeyCode.delete {
                buffer.deleteLastCharacter()
                return .passthrough
            }

            // Letter replace
            if letterActive {
                let charStr = String(character)
                if letterCI {
                    // Case-insensitive: lowercase key ile bak, ardından case uygula
                    let key = charStr.lowercased()
                    if let raw = snapshot.ciLetterRules[key] {
                        let replacement = CaseMapper.applyCase(of: character, to: raw)
                        return .replaceCharacter(replacement)
                    }
                } else {
                    if let replacement = snapshot.letterRules[charStr] {
                        return .replaceCharacter(replacement)
                    }
                }
            }

            // Word replace
            if wordActive {
                if isWordTerminator(character: character, keyCode: keyCode) {
                    let word = buffer.flush()
                    if !word.isEmpty {
                        if wordCI {
                            let key = word.lowercased()
                            if let raw = snapshot.ciWordRules[key] {
                                let replacement = CaseMapper.applyCase(of: word, to: raw)
                                return .replaceWord(deleteCount: word.count, insert: replacement, terminator: character)
                            }
                        } else {
                            if let replacement = snapshot.wordRules[word] {
                                return .replaceWord(deleteCount: word.count, insert: replacement, terminator: character)
                            }
                        }
                    }
                    return .passthrough
                } else {
                    buffer.append(character)
                    return .bufferOnly
                }
            }

            return .passthrough
        }
    }

    func clear() {
        lock.withLock { buffer.clear() }
    }
}

// MARK: - ReplaceEngine Actor

actor ReplaceEngine {

    static let shared = ReplaceEngine(
        dictionary: DictionaryStore.shared,
        settings: SettingsStore.shared
    )

    private var wordBuffer = WordBuffer()
    private let dictionary: DictionaryStore
    private let settings: SettingsStore
    private nonisolated let syncState = SynchronousReplaceState()

    init(dictionary: DictionaryStore, settings: SettingsStore) {
        self.dictionary = dictionary
        self.settings = settings
    }

    // MARK: - Public API (async — actor context, unit test için)

    func process(character: Character, keyCode: Int64) -> ReplaceAction {
        let snapshot     = dictionary.cachedSnapshot
        let letterActive = settings.isLetterReplaceActiveCached
        let wordActive   = settings.isWordReplaceActiveCached
        let letterCI     = settings.isLetterCaseInsensitiveCached
        let wordCI       = settings.isWordCaseInsensitiveCached

        if keyCode == KeyCode.escape {
            wordBuffer.clear()
            return .passthrough
        }
        if keyCode == KeyCode.delete {
            wordBuffer.deleteLastCharacter()
            return .passthrough
        }

        if letterActive {
            let charStr = String(character)
            if letterCI {
                let key = charStr.lowercased()
                if let raw = snapshot.ciLetterRules[key] {
                    return .replaceCharacter(CaseMapper.applyCase(of: character, to: raw))
                }
            } else {
                if let replacement = snapshot.letterRules[charStr] {
                    return .replaceCharacter(replacement)
                }
            }
        }

        if wordActive {
            if isWordTerminator(character: character, keyCode: keyCode) {
                let word = wordBuffer.flush()
                if !word.isEmpty {
                    if wordCI {
                        let key = word.lowercased()
                        if let raw = snapshot.ciWordRules[key] {
                            return .replaceWord(deleteCount: word.count, insert: CaseMapper.applyCase(of: word, to: raw), terminator: character)
                        }
                    } else {
                        if let replacement = snapshot.wordRules[word] {
                            return .replaceWord(deleteCount: word.count, insert: replacement, terminator: character)
                        }
                    }
                }
                return .passthrough
            } else {
                wordBuffer.append(character)
                return .bufferOnly
            }
        }
        return .passthrough
    }

    /// TASK-19: Focus değişimi veya motor kapandığında buffer'ı temizle.
    func clearBuffer() {
        wordBuffer.clear()
        syncState.clear()
        log.debug("WordBuffer cleared")
    }

    // MARK: - Synchronous entry (CGEventTap callback'ten çağrılır — async yok)

    nonisolated func processSynchronous(character: Character, keyCode: Int64) -> ReplaceAction {
        syncState.process(character: character, keyCode: keyCode)
    }
}

