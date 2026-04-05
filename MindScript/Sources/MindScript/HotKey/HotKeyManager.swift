import AppKit
import HotKey
import os

/// Manages the global Control+0 hotkey registration.
/// On press → starts recording and captures the frontmost app.
/// On release → stops recording and kicks off transcription.
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKey: HotKey?
    /// The app that was focused when the user pressed Control+0.
    private(set) var capturedApp: NSRunningApplication?

    private init() {}

    func register() {
        hotKey = HotKey(key: .zero, modifiers: .control)

        hotKey?.keyDownHandler = { [weak self] in
            guard let self else { return }
            // Capture the frontmost app before we do anything that might steal focus
            self.capturedApp = NSWorkspace.shared.frontmostApplication
            Logger.app.info("Hotkey pressed — captured app: \(self.capturedApp?.bundleIdentifier ?? "unknown")")
            RecordingManager.shared.startRecording()
        }

        hotKey?.keyUpHandler = { [weak self] in
            guard let self else { return }
            Logger.app.info("Hotkey released — stopping recording")
            RecordingManager.shared.stopRecording()
        }

        Logger.app.info("Global hotkey Control+0 registered")
    }

    func unregister() {
        hotKey = nil
    }
}
