// SettingsWindowController.swift — NSWindowController wrapper

import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {

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
    }
}
