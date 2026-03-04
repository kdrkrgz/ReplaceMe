// AppDelegate.swift — Application entry point (AppKit, no SwiftUI)

import AppKit
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "AppDelegate")
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock'ta görünme — LSUIElement=YES destekçisi
        NSApp.setActivationPolicy(.accessory)

        // Ana menü — programmatik AppKit uygulamalarında mainMenu nil olur.
        // Edit menüsü olmadan Cmd+C/V/X/A/Z key equivalentları NSTextView'a ulaşmaz
        // çünkü AppKit key equivalent dispatch'i mainMenu üzerinden çalışır.
        setupMainMenu()

        // Accessibility izni kontrolü
        AccessibilityChecker.requestIfNeeded()

        // DictionaryStore yükle (async, actor)
        Task {
            do {
                try await DictionaryStore.shared.load()
                log.info("DictionaryStore loaded")
            } catch {
                log.error("DictionaryStore load failed: \(error.localizedDescription)")
            }
        }

        // Menubar kur
        statusBarController = StatusBarController()

        // CGEventTap başlat
        do {
            try InputManager.shared.start()
            log.info("InputManager started")
        } catch {
            log.error("InputManager start failed: \(error.localizedDescription)")
        }

        // NSServices provider kaydet
        NSApp.servicesProvider = ServiceHandler.shared
        NSUpdateDynamicServices()

        // Focus değişiminde WordBuffer temizle
        FocusChangeMonitor.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        InputManager.shared.stop()
        log.info("InputManager stopped on termination")
    }

    // MARK: - Main Menu

    /// Programmatik AppKit uygulamalarında mainMenu yoktur (XIB/Storyboard yok).
    /// Edit menüsü olmadan, Cmd+C/V/X/A/Z gibi key equivalentlar NSTextView'a iletilmez.
    /// AppKit event dispatch: NSApp.sendEvent → performKeyEquivalent → mainMenu.performKeyEquivalent
    /// mainMenu nil ise key equivalent sessizce düşer.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Application menüsü
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About ReplaceMe",
                                    action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                                    keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit ReplaceMe",
                                    action: #selector(NSApplication.terminate(_:)),
                                    keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menüsü — NSTextView key equivalent dispatch için zorunlu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenu.addItem(.separator())
        // Find — NSTextFinder tag-based dispatch (usesFindBar = true ile inline bar açılır)
        let findItem = NSMenuItem(title: "Find…",
                                   action: #selector(NSTextView.performFindPanelAction(_:)),
                                   keyEquivalent: "f")
        findItem.tag = NSTextFinder.Action.showFindInterface.rawValue
        editMenu.addItem(findItem)
        let findNextItem = NSMenuItem(title: "Find Next",
                                      action: #selector(NSTextView.performFindPanelAction(_:)),
                                      keyEquivalent: "g")
        findNextItem.tag = NSTextFinder.Action.nextMatch.rawValue
        editMenu.addItem(findNextItem)
        let findPrevItem = NSMenuItem(title: "Find Previous",
                                      action: #selector(NSTextView.performFindPanelAction(_:)),
                                      keyEquivalent: "G")  // Cmd+Shift+G
        findPrevItem.tag = NSTextFinder.Action.previousMatch.rawValue
        editMenu.addItem(findPrevItem)
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
