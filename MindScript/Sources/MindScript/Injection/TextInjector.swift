import AppKit
import CoreGraphics
import os

/// Injects text at the current cursor position using two strategies:
///
/// **Strategy A — CGEvent Unicode injection (default)**
/// Sends key-down/key-up pairs with Unicode scalars directly. Works in most
/// text fields without requiring any special permissions.
///
/// **Strategy B — NSPasteboard + Cmd+V (fallback)**
/// Copies text to the clipboard and simulates Cmd+V. Requires Accessibility
/// permission. Used for apps that don't respond well to CGEvent injection
/// (e.g., some Electron apps, terminal emulators).
enum TextInjector {
    // MARK: - Public entry point

    @MainActor
    static func inject(text: String, into app: NSRunningApplication? = nil) {
        guard !text.isEmpty else { return }

        // Re-activate the target app before injecting
        if let app {
            app.activate(options: .activateIgnoringOtherApps)
        }

        Task { @MainActor in
            // Short delay to let the window come to front
            try? await Task.sleep(for: .milliseconds(Constants.injectionActivationDelayMs))

            if Permissions.accessibilityEnabled {
                pasteboardInject(text: text)
            } else {
                cgEventInject(text: text)
            }

            Logger.injection.info("Injected \(text.count) characters into \(app?.bundleIdentifier ?? "focused app")")
        }
    }

    // MARK: - CGEvent injection

    private static func cgEventInject(text: String) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            Logger.injection.error("Could not create CGEventSource")
            return
        }

        for scalar in text.unicodeScalars {
            var utf16: [UniChar] = Array(String(scalar).utf16)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            keyDown?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            keyDown?.post(tap: .cghidEventTap)

            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            keyUp?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Pasteboard + Cmd+V injection

    private static func pasteboardInject(text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)   // 0x09 = V
        cmdVDown?.flags = .maskCommand
        cmdVDown?.post(tap: .cghidEventTap)

        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        cmdVUp?.flags = .maskCommand
        cmdVUp?.post(tap: .cghidEventTap)

        // Restore clipboard after a short delay so we don't permanently clobber it
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            // Only restore if nobody else touched the clipboard
            if NSPasteboard.general.changeCount == previousChangeCount + 1,
               let prev = previousContents {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(prev, forType: .string)
            }
        }
    }
}
