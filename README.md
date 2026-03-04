# ReplaceMe

A lightweight macOS menu bar utility that intercepts keyboard input system-wide and performs real-time text replacement — both at the character level and at the word level — using a user-defined dictionary.

---

## Features

- **Character replacement** — replace individual keystrokes as you type (e.g. `ş` → `s`)
- **Word replacement** — replace completed words on word-terminator keystrokes (space, punctuation, return)
- **Case-aware matching** — optional case-insensitive matching with configurable title-case and uppercase propagation
- **Global hotkey** — toggle the engine on/off from anywhere via a configurable hotkey
- **Status bar UI** — lives exclusively in the menu bar (no Dock icon)
- **NSServices integration** — right-click selected text → *RM – Sözlüğe Ekle* to add words directly from any app
- **CSV import/export** — manage your replacement dictionary as a plain CSV file
- **No sandbox** — requires Accessibility permission for `CGEventTap`; runs without App Sandbox

---

## Requirements

| Requirement | Value |
|---|---|
| macOS | 14.6 Sonoma or later |
| Xcode | 15 or later |
| Swift | 5.0 |
| Entitlements | Accessibility (CGEventTap); App Sandbox **disabled** |

---

## Architecture

```
ReplaceMe/
├── App/                    # AppDelegate, main.swift
├── Domain/                 # ReplaceEngine (actor), WordBuffer, ReplaceAction, CaseMapper
├── Infrastructure/         # InputManager (CGEventTap), EventInjector, AccessibilityChecker,
│                           # FocusChangeMonitor, SystemShortcutChecker
├── Data/                   # DictionaryStore (actor), SettingsStore, CSVService, Models
└── UI/
    ├── StatusBar/          # StatusBarController (NSStatusItem)
    ├── Settings/           # SettingsWindowController / SettingsViewController
    ├── Popup/              # AddWordPopupController
    ├── HotkeyRecorder/     # HotkeyRecorderWindowController / ViewController
    └── Services/           # ServiceHandler (NSServices provider)
```

### Key design decisions

- **`CGEventTap` on a dedicated thread** — keyboard events are intercepted at the lowest level before reaching the target app. The tap callback is synchronous and lock-protected (`SynchronousReplaceState`).
- **Actor isolation** — `DictionaryStore` and `ReplaceEngine` are Swift actors; UI mutations are dispatched to `@MainActor`.
- **Cached snapshots** — `DictionaryStore` and `SettingsStore` expose lock-free cached values that the synchronous tap callback reads without async overhead.
- **No force-unwrap** — all optional handling uses safe `guard`/`if let` throughout.
- **OSLog** — structured logging with subsystem `com.kadirkaragoz.ReplaceMe` and per-component categories.

---

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/<your-username>/ReplaceMe.git
   cd ReplaceMe
   ```
2. Open the project in Xcode:
   ```bash
   open ReplaceMe.xcodeproj
   ```
3. Select your development team in *Signing & Capabilities*.
4. Build & Run (`⌘R`).
5. On first launch, macOS will prompt for **Accessibility** permission — grant it in *System Settings → Privacy & Security → Accessibility*.

---

## Dictionary Format

The replacement dictionary is stored as a CSV file and can be exported/imported from the Settings window.

```
from,to,type
ş,s,letter
tşk,teşekkürler,word
```

| Column | Description |
|---|---|
| `from` | Source text (character or word) |
| `to` | Replacement text |
| `type` | `letter` or `word` |

---

## Permissions

ReplaceMe requires **Accessibility access** to install a `CGEventTap`. Without this permission the engine will not start and no replacements will occur.

- Go to **System Settings → Privacy & Security → Accessibility**
- Enable **ReplaceMe**

The app runs **without App Sandbox** (`com.apple.security.app-sandbox = false`) because `CGEventTap` cannot be used from within a sandboxed process.

---

## Contributing

1. Fork the repository and create a feature branch.
2. Run tests before opening a pull request:
   ```bash
   xcodebuild test -scheme ReplaceMe -destination 'platform=macOS'
   ```
3. Follow the commit message convention:
   ```
   RM-<issue>: short imperative description
   ```

---

## License

MIT — see [LICENSE](LICENSE) for details.
