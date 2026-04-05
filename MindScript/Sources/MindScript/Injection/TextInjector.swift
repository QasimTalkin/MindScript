import AppKit
import CoreGraphics
import os

enum TextInjector {

    // MARK: - Streaming injection (target app stays focused)

    @MainActor
    static func injectImmediate(text: String) {
        guard !text.isEmpty else { return }
        paste(text)
    }

    // MARK: - Final injection (re-activates the captured app first)

    @MainActor
    static func inject(text: String, into app: NSRunningApplication?) {
        guard !text.isEmpty else { return }
        Task { @MainActor in
            if let app, app.bundleIdentifier != Bundle.main.bundleIdentifier {
                app.activate()
                try? await Task.sleep(for: .milliseconds(300))
            }
            paste(text)
            Logger.injection.info("Injected \(text.count) chars")
        }
    }

    // MARK: - Core paste

    private static func paste(_ text: String) {
        let pb = NSPasteboard.general
        let previous = pb.string(forType: .string)
        let countBefore = pb.changeCount
        pb.clearContents()
        pb.setString(text, forType: .string)

        if AXIsProcessTrusted() {
            sendCmdV()
        } else {
            let ok = pasteViaAppleScript()
            if !ok {
                AppState.shared.errorMessage = "needs_accessibility"
                NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
            }
        }

        Task {
            try? await Task.sleep(for: .milliseconds(700))
            if NSPasteboard.general.changeCount == countBefore + 1, let prev = previous {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(prev, forType: .string)
            }
        }
    }

    // MARK: - Cmd+V via CGEvent

    private static func sendCmdV() {
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return }
        let down = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: - AppleScript fallback

    @discardableResult
    private static func pasteViaAppleScript() -> Bool {
        let source = "tell application \"System Events\" to keystroke v using command down"
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }
}
