import AppKit
import CoreGraphics
import os

enum TextInjector {

    // MARK: - Streaming injection (target app stays focused, overlay is non-activating)

    @MainActor
    static func injectImmediate(text: String) {
        guard !text.isEmpty else { return }
        paste(text)
    }

    // MARK: - Final injection (called after recording stops)
    // Re-activates the captured app before pasting so text lands in the right place.

    @MainActor
    static func inject(text: String, into app: NSRunningApplication?) {
        guard !text.isEmpty else { return }

        Task { @MainActor in
            if let app, app.bundleIdentifier != Bundle.main.bundleIdentifier {
                app.activate()
                try? await Task.sleep(for: .milliseconds(300))
            }
            paste(text)
            Logger.injection.info("Injected \(text.count) chars into \(app?.bundleIdentifier ?? "frontmost")")
        }
    }

    // MARK: - Core paste logic with layered fallbacks

    private static func paste(_ text: String) {
        // Set clipboard
        let pb = NSPasteboard.general
        let previousContents = pb.string(forType: .string)
        let countBefore = pb.changeCount
        pb.clearContents()
        pb.setString(text, forType: .string)

        // Layer 1: CGEvent Cmd+V (works when Accessibility is granted)
        if AXIsProcessTrusted() {
            sendCmdV()
            Logger.injection.debug("CGEvent paste: \(text.count) chars")
        } else {
            // Layer 2: AppleScript via System Events (different permission path)
            let didPaste = pasteViaAppleScript()
            if !didPaste {
                // Layer 3: Text is on clipboard — notify user to press ⌘V
                Logger.injection.warning("All injection methods failed — text is on clipboard")
                AppState.shared.errorMessage = "needs_accessibility"
                NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
            } else {
                Logger.injection.debug("AppleScript paste: \(text.count) chars")
            }
        }

        // Restore previous clipboard contents after paste is consumed
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            if NSPasteboard.general.changeCount == countBefore + 1, let prev = previousContents {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(prev, forType: .string)
            }
        }
    }

    // MARK: - Cmd+V via CGEvent

    private static func sendCmdV() {
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return }
        // Virtual key 9 = V on all keyboard layouts
        let down = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: - AppleScript fallback via System Events

    @discardableResult
    private static func pasteViaAppleScript() -> Bool {
        let source = """
        tell application "System Events"
            keystroke v using command down
        end tell
        """
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let err = error {
            Logger.injection.error("AppleScript paste error: \(err)")
            return false
        }
        return true
    }
}
