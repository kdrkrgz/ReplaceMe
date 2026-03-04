// AccessibilityChecker.swift — Accessibility izni kontrolü ve yönlendirme

import AppKit
import ApplicationServices
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "Accessibility")

enum AccessibilityChecker {

    static func isGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// İzin yoksa sistem diyaloğunu aç ve kullanıcıya alert göster.
    static func requestIfNeeded() {
        guard !isGranted() else {
            log.info("Accessibility permission already granted")
            return
        }

        log.warning("Accessibility permission not granted — prompting user")

        // macOS sistem diyaloğunu tetikle
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)

        showPermissionAlert()
    }

    private static func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
                ReplaceMe needs Accessibility access to intercept and replace keystrokes system-wide.

                Please grant access in:
                System Settings → Privacy & Security → Accessibility

                Restart the app after granting permission.
                """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Quit")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                openPrivacySettings()
            } else {
                NSApp.terminate(nil)
            }
        }
    }

    static func openPrivacySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
