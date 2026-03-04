// SettingsWindowController.swift — NSWindowController wrapper

import AppKit
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "SettingsWindow")

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ReplaceMe Settings"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        self.contentViewController = SettingsViewController()
        window.delegate = self
    }

    override func showWindow(_ sender: Any?) {
        // LSUIElement / .accessory uygulamalar window server'da düzgün keyboard focus alamaz.
        // Settings açıkken .regular'a geçip uygulamayı aktive ediyoruz,
        // böylece Cmd+C, Cmd+A gibi kısayollar NSTextView'a ulaşır.
        NSApp.setActivationPolicy(.regular)

        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)

        if let vc = contentViewController as? SettingsViewController {
            window?.makeFirstResponder(vc.firstEditableView)
        }
        log.debug("Settings window shown with .regular activation policy")
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            // Settings kapandığında tekrar .accessory'ye dön — Dock ikonu kaybolur
            SettingsStore.shared.isEditingLetterRulesCached = false
            NSApp.setActivationPolicy(.accessory)
            log.debug("Settings window closed — reverted to .accessory activation policy")
        }
    }

    nonisolated func windowDidResignKey(_ notification: Notification) {
        // Settings penceresi arka plana geçtiğinde letter bypass flag'ini sıfırla
        Task { @MainActor in
            SettingsStore.shared.isEditingLetterRulesCached = false
        }
    }
}
