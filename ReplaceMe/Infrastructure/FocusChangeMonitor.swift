// FocusChangeMonitor.swift — Uygulama focus değişiminde WordBuffer temizleme (TASK-19)

import AppKit
import OSLog

private let log = Logger(subsystem: "com.kadirkaragoz.ReplaceMe", category: "FocusMonitor")

/// AppDelegate'den başlatılır. Workspace notification'larını dinleyerek
/// focus değiştiğinde ReplaceEngine buffer'ını temizler.
final class FocusChangeMonitor {

    static let shared = FocusChangeMonitor()

    private init() {}

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        log.debug("FocusChangeMonitor started")
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func activeAppChanged(_ notification: Notification) {
        Task {
            await ReplaceEngine.shared.clearBuffer()
            log.debug("WordBuffer cleared on app focus change")
        }
    }
}
