// AppDelegate.swift — Application entry point (AppKit, no SwiftUI)

import AppKit
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "AppDelegate")
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock'ta görünme — LSUIElement=YES destekçisi
        NSApp.setActivationPolicy(.accessory)

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
}
