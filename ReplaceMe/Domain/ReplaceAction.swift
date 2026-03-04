// ReplaceAction.swift — Replace işleminin sonuç tipini temsil eder

/// CGEventTap callback'inin dönmesi gereken aksiyonu tanımlar.
/// Equatable: unit test assertion için.
enum ReplaceAction: Equatable {
    /// Event'e müdahale etme, olduğu gibi geç.
    case passthrough

    /// Karakteri sadece WordBuffer'a ekle; event'i geçir (kelime tamamlanmadı).
    case bufferOnly

    /// Orijinal event'i yut, verilen string'i inject et (harf replace).
    case replaceCharacter(String)

    /// Orijinal (terminator) event'i yut:
    /// - `deleteCount` adet backspace gönder,
    /// - `insert` string'i inject et,
    /// - `terminator` varsa onu da inject et.
    case replaceWord(deleteCount: Int, insert: String, terminator: Character?)
}
