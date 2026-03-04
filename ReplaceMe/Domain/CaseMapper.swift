// CaseMapper.swift — Case pattern detection and case-preserving replacement

import Foundation

// MARK: - CasePattern

/// Kullanıcının yazdığı kelimenin/karakterin case pattern'ı.
enum CasePattern {
    /// "sukur", "şükür"  — tamamı küçük harf
    case allLowercase
    /// "Sukur", "Şükür"  — ilk harf büyük, geri kalan küçük
    case titleCase
    /// "SUKUR", "ŞÜKÜR"  — tamamı büyük harf
    case allUppercase
    /// "SuKuR"           — karışık; titleCase muamelesi yapılır
    case mixed
}

// MARK: - CaseMapper

/// Pure value-type utility — CGEventTap callback dahil her thread'de güvenli.
enum CaseMapper {

    // MARK: - Pattern Detection

    /// Verilen string'in case pattern'ını saptar.
    static func detect(_ s: String) -> CasePattern {
        guard !s.isEmpty else { return .allLowercase }

        let lower = s.lowercased()
        let upper = s.uppercased()

        if s == lower {
            return .allLowercase
        }
        if s == upper {
            return .allUppercase
        }
        // İlk harf büyük, geri kalan küçük mü?
        let firstUpper = String(s.prefix(1)).uppercased()
        let restLower  = String(s.dropFirst()).lowercased()
        if s == firstUpper + restLower {
            return .titleCase
        }
        return .mixed
    }

    // MARK: - Case Application

    /// Tespit edilen pattern'ı replacement string'e uygula.
    static func apply(pattern: CasePattern, to replacement: String) -> String {
        guard !replacement.isEmpty else { return replacement }
        switch pattern {
        case .allLowercase:
            return replacement.lowercased()
        case .allUppercase:
            return replacement.uppercased()
        case .titleCase, .mixed:
            // İlk karakteri büyüt, geri kalanı olduğu gibi bırak (replacement zaten doğru yazılmış)
            let first = String(replacement.prefix(1)).uppercased()
            let rest  = String(replacement.dropFirst())
            return first + rest
        }
    }

    /// Filtered applyCase — CI aktifken sadece seçili case pattern'ları transform eder.
    /// capitalActive=false → title-case input için replacement olduğu gibi döner.
    /// uppercaseActive=false → ALL-CAPS input için replacement olduğu gibi döner.
    static func applyCase(of original: String, to replacement: String,
                           capitalActive: Bool, uppercaseActive: Bool) -> String {
        guard !replacement.isEmpty else { return replacement }
        let pattern = detect(original)
        switch pattern {
        case .allLowercase, .mixed:
            return replacement
        case .titleCase:
            return capitalActive ? apply(pattern: .titleCase, to: replacement) : replacement
        case .allUppercase:
            return uppercaseActive ? apply(pattern: .allUppercase, to: replacement) : replacement
        }
    }

    /// Karakter varyantı — letter replace CI path için.
    static func applyCase(of original: Character, to replacement: String,
                           capitalActive: Bool, uppercaseActive: Bool) -> String {
        applyCase(of: String(original), to: replacement,
                  capitalActive: capitalActive, uppercaseActive: uppercaseActive)
    }

    /// Kısayol: original string'den pattern'ı oku, replacement'a uygula.
    /// - Parameters:
    ///   - original: Kullanıcının yazdığı kelime/karakter (orijinal case).
    ///   - replacement: Sözlükteki (lowercase) replace değeri.
    static func applyCase(of original: String, to replacement: String) -> String {
        apply(pattern: detect(original), to: replacement)
    }

    /// Karakter varyantı — letter replace için.
    static func applyCase(of original: Character, to replacement: String) -> String {
        applyCase(of: String(original), to: replacement)
    }
}
