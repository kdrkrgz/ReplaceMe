// StatusBarController.swift — NSStatusItem menubar controller

import AppKit
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "StatusBar")

@MainActor
final class StatusBarController: NSObject {

    private let statusItem: NSStatusItem
    private var settingsWindowController: SettingsWindowController?
    private var hotkeyRecorderWindowController: HotkeyRecorderWindowController?
    private let settings = SettingsStore.shared

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        setupButton()
        setupMenu()
        updateIcon()

        // SettingsStore değişimlerini dinle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: .rmSettingsChanged,
            object: nil
        )
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.action = #selector(statusItemClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Active toggle
        let activeItem = NSMenuItem(title: "Active", action: #selector(toggleGlobal), keyEquivalent: "")
        activeItem.target = self
        activeItem.tag = 100
        menu.addItem(activeItem)

        menu.addItem(.separator())

        // Letter Replace checkbox
        let letterItem = NSMenuItem(title: "Letter Replace Active", action: #selector(toggleLetterReplace), keyEquivalent: "")
        letterItem.target = self
        letterItem.tag = 102
        menu.addItem(letterItem)

        // Letter Replace CI checkbox (indented title ile görsel ayrım)
        let letterCIItem = NSMenuItem(title: "  Case Insensitive", action: #selector(toggleLetterCI), keyEquivalent: "")
        letterCIItem.target = self
        letterCIItem.tag = 103
        menu.addItem(letterCIItem)

        menu.addItem(.separator())

        // Word Replace checkbox
        let wordItem = NSMenuItem(title: "Word Replace Active", action: #selector(toggleWordReplace), keyEquivalent: "")
        wordItem.target = self
        wordItem.tag = 101
        menu.addItem(wordItem)

        // Word Replace CI checkbox
        let wordCIItem = NSMenuItem(title: "  Case Insensitive", action: #selector(toggleWordCI), keyEquivalent: "")
        wordCIItem.target = self
        wordCIItem.tag = 104
        menu.addItem(wordCIItem)

        menu.addItem(.separator())

        // Settings
        let shortcutItem = NSMenuItem(title: "Activate Shortcut...", action: #selector(openShortcutRecorder), keyEquivalent: "")
        shortcutItem.target = self
        shortcutItem.tag = 105
        menu.addItem(shortcutItem)

        menu.addItem(NSMenuItem(title: "Open Settings...", action: #selector(openSettings), keyEquivalent: ",").then {
            $0.target = self
        })

        menu.addItem(.separator())

        // Quit
        menu.addItem(NSMenuItem(title: "Quit ReplaceMe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Delegate — menu açılırken state güncelle
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - Icon

    func updateIcon() {
        let active = settings.isGlobalActive
        let symbolName = active ? "keyboard.fill" : "keyboard"
        statusItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "ReplaceMe")
        statusItem.button?.alphaValue = active ? 1.0 : 0.4
    }

    // MARK: - Actions

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        // Left click → toggle; right click → show menu (handled by NSMenu default)
    }

    @objc private func toggleGlobal() {
        settings.isGlobalActive.toggle()
        if !settings.isGlobalActive {
            Task { await ReplaceEngine.shared.clearBuffer() }
        }
        updateIcon()
        updateMenuState()
        log.info("Global active: \(self.settings.isGlobalActive)")
    }

    @objc private func toggleWordReplace() {
        settings.isWordReplaceActive.toggle()
        updateMenuState()
    }

    @objc private func toggleLetterReplace() {
        settings.isLetterReplaceActive.toggle()
        updateMenuState()
    }

    @objc private func toggleLetterCI() {
        settings.isLetterCaseInsensitive.toggle()
        updateMenuState()
    }

    @objc private func toggleWordCI() {
        settings.isWordCaseInsensitive.toggle()
        updateMenuState()
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
    }

    @objc private func openShortcutRecorder() {
        if hotkeyRecorderWindowController == nil {
            hotkeyRecorderWindowController = HotkeyRecorderWindowController()
        }
        hotkeyRecorderWindowController?.show()
    }

    @objc private func settingsDidChange() {
        updateIcon()
        updateMenuState()
    }

    // MARK: - Menu State

    private func updateMenuState() {
        guard let menu = statusItem.menu else { return }

        if let activeItem = menu.item(withTag: 100) {
            activeItem.state = settings.isGlobalActive ? .on : .off
        }
        if let letterItem = menu.item(withTag: 102) {
            letterItem.state = settings.isLetterReplaceActive ? .on : .off
        }
        if let letterCIItem = menu.item(withTag: 103) {
            letterCIItem.state = settings.isLetterCaseInsensitive ? .on : .off
            // CI checkbox sadece letter replace aktifken anlamlı — grayed out değil, bilgi amaçlı
        }
        if let wordItem = menu.item(withTag: 101) {
            wordItem.state = settings.isWordReplaceActive ? .on : .off
        }
        if let wordCIItem = menu.item(withTag: 104) {
            wordCIItem.state = settings.isWordCaseInsensitive ? .on : .off
        }
        // Update "Activate Shortcut" title to reflect current shortcut
        if let shortcutItem = menu.item(withTag: 105) {
            if let combo = settings.activationShortcut {
                shortcutItem.title = "Activate Shortcut: \(combo.displayString)"
            } else {
                shortcutItem.title = "Activate Shortcut..."
            }
        }
    }
}

// MARK: - NSMenuDelegate

extension StatusBarController: NSMenuDelegate {
    nonisolated func menuWillOpen(_ menu: NSMenu) {
        Task { @MainActor in
            self.updateMenuState()
            self.updateIcon()
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let rmSettingsChanged = Notification.Name("rmSettingsChanged")
}

// MARK: - NSMenuItem builder helper

private extension NSMenuItem {
    @discardableResult
    func then(_ configure: (NSMenuItem) -> Void) -> NSMenuItem {
        configure(self)
        return self
    }
}
