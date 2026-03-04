// ServiceHandler.swift — NSServices entegrasyon handler'ı

import AppKit
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "Services")

/// NSServices provider — `addToRMDictionary:userData:error:` selector'ı karşılar.
final class ServiceHandler: NSObject {

    static let shared = ServiceHandler()

    private override init() {}

    @objc func addToRMDictionary(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) {
        guard let selectedText = pasteboard.string(forType: .string),
              !selectedText.isEmpty else {
            log.warning("Services: empty pasteboard, ignoring")
            return
        }

        log.info("Services: received '\(selectedText)' — showing popup")

        DispatchQueue.main.async {
            AddWordPopupController.show(forWord: selectedText)
        }
    }
}
