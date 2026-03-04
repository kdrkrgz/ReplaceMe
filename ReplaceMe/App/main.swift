// main.swift — AppKit uygulama başlangıç noktası
// Bu dosyanın adı "main.swift" olmak ZORUNDA (Swift entry point kuralı).

import AppKit

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
