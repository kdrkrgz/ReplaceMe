// URLImportService.swift — URL'den word replace kurallarını çeker, normalize eder ve validate eder

import Foundation
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "URLImport")

enum URLImportError: LocalizedError {
    case invalidURL(String)
    case networkError(String)
    case emptyResponse
    case noValidRules
    case formatError(String)
    case validationErrors([String])

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Geçersiz URL: \(url)"
        case .networkError(let detail):
            return "Ağ hatası: \(detail)"
        case .emptyResponse:
            return "URL boş yanıt döndü."
        case .noValidRules:
            return "Geçerli kural bulunamadı. Format: her satır from,to şeklinde olmalı."
        case .formatError(let detail):
            return "Format hatası: \(detail)"
        case .validationErrors(let errors):
            let header = "\(errors.count) satırda hata bulundu:\n"
            return header + errors.joined(separator: "\n")
        }
    }
}

/// Tek bir satırın validasyon sonucu.
struct LineValidation {
    let lineNumber: Int
    let raw: String
    let error: String?
}

enum URLImportService {

    // Tek satırlık verilerde kural çiftlerini ayırmak için kullanılan separator'lar.
    // Sıralama: önce `-`, sonra `.`, sonra boşluk.
    private static let ruleSeparators: [Character] = ["-", ".", " "]

    /// URL'den word replace kurallarını async olarak çeker, normalize eder ve validate eder.
    /// Geçersiz satır varsa `.validationErrors` fırlatır.
    static func fetchRules(from urlString: String) async throws -> [String: String] {
        guard let url = URL(string: urlString), url.scheme == "http" || url.scheme == "https" else {
            throw URLImportError.invalidURL(urlString)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw URLImportError.networkError(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLImportError.networkError("HTTP \(http.statusCode)")
        }

        guard !data.isEmpty else {
            throw URLImportError.emptyResponse
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw URLImportError.formatError("Dosya UTF-8 olarak okunamadı.")
        }

        // Normalize: tek satır halindeki veriyi satırlara böl
        let lines = normalizeContent(content)

        guard !lines.isEmpty else {
            throw URLImportError.noValidRules
        }

        // Her satırı validate et
        var rules: [String: String] = [:]
        var errors: [String] = []

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let validation = validateImportLine(trimmed, lineNumber: index + 1)
            if let error = validation.error {
                errors.append(error)
                continue
            }

            // Parse: tam olarak 1 virgül, trim edilmiş from/to
            let parts = trimmed.split(separator: ",", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
            rules[parts[0]] = parts[1]
        }

        if !errors.isEmpty {
            throw URLImportError.validationErrors(errors)
        }

        guard !rules.isEmpty else {
            throw URLImportError.noValidRules
        }

        log.info("Fetched \(rules.count) rules from \(urlString)")
        return rules
    }

    // MARK: - Content Normalization

    /// İçeriği satırlara normalize eder.
    /// Eğer veri zaten çok satırlıysa (newline içeriyorsa), satır bazında döner.
    /// Eğer tek satırsa, separator karakter (`-`, `.`, boşluk) ile kural çiftlerini ayırır.
    /// Separator tespiti: `from,to` çiftlerinden sonra gelen ilk separator.
    static func normalizeContent(_ content: String) -> [String] {
        let rawLines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Çok satırlı → doğrudan döndür
        if rawLines.count > 1 {
            return rawLines
        }

        // Tek satır → separator ile bölmeyi dene
        guard let singleLine = rawLines.first else { return [] }

        // Virgül sayısına bak: eğer 2+ virgül varsa ve bir separator bulunabiliyorsa böl
        let commaCount = singleLine.filter { $0 == "," }.count
        guard commaCount >= 2 else {
            // 0 veya 1 virgül → tek satır olarak döndür (validate aşamasında kontrol edilir)
            return [singleLine]
        }

        // `from,to` çiftlerini ayıran separator'ı bul.
        // Strateji: ilk `from,to` çiftinden sonraki ilk separator karakteri kontrol et.
        // Örn: "tsk,tesekkurler-ok,tamam" → ilk çiftin sonundaki separator: "-"
        for sep in ruleSeparators {
            let parts = trySplitBySeparator(singleLine, separator: sep)
            if parts.count >= 2 && parts.allSatisfy({ isValidRulePair($0) }) {
                return parts
            }
        }

        // Hiçbir separator çalışmadı → tek satır olarak dön (validate hatası verir)
        return [singleLine]
    }

    /// Tek satırı verilen separator ile `from,to` çiftlerine böler.
    private static func trySplitBySeparator(_ line: String, separator: Character) -> [String] {
        // Split by separator, then rejoin if a part doesn't have exactly 1 comma.
        // "tsk,tesekkurler-ok,tamam" → ["tsk,tesekkurler", "ok,tamam"]
        let candidates = line.split(separator: separator).map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
        return candidates
    }

    /// `from,to` formatında geçerli bir çift mi kontrol eder.
    private static func isValidRulePair(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let commaCount = trimmed.filter { $0 == "," }.count
        guard commaCount == 1 else { return false }
        let parts = trimmed.split(separator: ",", maxSplits: 1).map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
        return parts.count == 2 && !parts[0].isEmpty && !parts[1].isEmpty
            && !parts[0].contains(" ") && !parts[1].contains(" ")
    }

    // MARK: - Line Validation

    /// Tek bir import satırını validate eder. SettingsViewController.validateWordLine ile aynı mantık.
    private static func validateImportLine(_ line: String, lineNumber: Int) -> LineValidation {
        let commaCount = line.filter { $0 == "," }.count

        if commaCount == 0 {
            return LineValidation(
                lineNumber: lineNumber, raw: line,
                error: "Satır \(lineNumber): Virgül bulunamadı — '\(line)'"
            )
        }

        if commaCount > 1 {
            return LineValidation(
                lineNumber: lineNumber, raw: line,
                error: "Satır \(lineNumber): Birden fazla virgül (\(commaCount)) — '\(line)'"
            )
        }

        let parts = line.split(separator: ",", maxSplits: 1).map {
            String($0).trimmingCharacters(in: .whitespaces)
        }

        if parts.count != 2 {
            return LineValidation(
                lineNumber: lineNumber, raw: line,
                error: "Satır \(lineNumber): Geçersiz format — '\(line)'"
            )
        }

        let from = parts[0], to = parts[1]

        if from.isEmpty {
            return LineValidation(
                lineNumber: lineNumber, raw: line,
                error: "Satır \(lineNumber): 'from' alanı boş — '\(line)'"
            )
        }

        if to.isEmpty {
            return LineValidation(
                lineNumber: lineNumber, raw: line,
                error: "Satır \(lineNumber): 'to' alanı boş — ',\(line.split(separator: ",").last ?? "")'"
            )
        }

        if from.contains(" ") {
            return LineValidation(
                lineNumber: lineNumber, raw: line,
                error: "Satır \(lineNumber): 'from' alanı birden fazla kelime içeriyor — '\(from)'"
            )
        }

        if to.contains(" ") {
            return LineValidation(
                lineNumber: lineNumber, raw: line,
                error: "Satır \(lineNumber): 'to' alanı birden fazla kelime içeriyor — '\(to)'"
            )
        }

        return LineValidation(lineNumber: lineNumber, raw: line, error: nil)
    }
}
