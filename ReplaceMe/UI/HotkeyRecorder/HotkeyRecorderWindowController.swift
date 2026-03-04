// HotkeyRecorderWindowController.swift — Window controller for hotkey recorder

import AppKit
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "HotkeyRecorderWC")

/// Manages the hotkey recorder window.
/// Follows the same `.regular`↔`.accessory` activation policy pattern as `SettingsWindowController`.
@MainActor
final class HotkeyRecorderWindowController: NSWindowController, NSWindowDelegate {

    init() {
        let vc = HotkeyRecorderViewController()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Activation Shortcut"
        window.isReleasedWhenClosed = false
        window.contentViewController = vc
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init()") }

    // MARK: - Show

    func show() {
        // Switch to regular app so the recorder window can receive keyboard focus
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        log.debug("Hotkey recorder window shown")
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Revert to menubar-only (LSUIElement) mode when window closes
        NSApp.setActivationPolicy(.accessory)
        log.debug("Hotkey recorder window closed — reverted to .accessory")
    }
}
