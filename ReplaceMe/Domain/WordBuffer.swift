// WordBuffer.swift — Kelime replace için karakter buffer'ı

/// Value type — ReplaceEngine actor içinde tutulur (actor isolation garantisi var).
struct WordBuffer {

    private var buffer: [Character] = []

    // MARK: - Mutations

    mutating func append(_ char: Character) {
        buffer.append(char)
    }

    /// Buffer'ı boşalt ve birikmiş kelimeyi döndür.
    mutating func flush() -> String {
        let word = String(buffer)
        buffer.removeAll(keepingCapacity: true)
        return word
    }

    /// Son karakteri sil (backspace ile kullanıcı sildi).
    mutating func deleteLastCharacter() {
        if !buffer.isEmpty {
            buffer.removeLast()
        }
    }

    /// Buffer'ı tamamen temizle (focus değişimi, Escape, motor kapandı).
    mutating func clear() {
        buffer.removeAll(keepingCapacity: true)
    }

    // MARK: - Read

    var isEmpty: Bool { buffer.isEmpty }
    var count: Int { buffer.count }
    var current: String { String(buffer) }
}
