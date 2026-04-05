import AppKit
import HotKey
import os

/// Manages the global hotkeys for MindScript.
///
/// Simple two-key flow:
/// - Press ⌃0 → start recording (captures the frontmost app at this moment)
/// - Press Escape → stop recording, transcribe, inject text at cursor
@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var triggerHotKey: HotKey?
    private var escapeHotKey: HotKey?

    /// The app that was focused when the user pressed ⌃0 to start recording.
    private(set) var capturedApp: NSRunningApplication?

    private init() {}

    func register() {
        // Control+0 → start recording only (ignored if already recording)
        triggerHotKey = HotKey(key: .zero, modifiers: .control)
        triggerHotKey?.keyDownHandler = { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard !AppState.shared.isRecording else { return }
                // Capture the app the user was working in before we do anything
                self.capturedApp = NSWorkspace.shared.frontmostApplication
                Logger.app.info("⌃0: starting recording, target=\(self.capturedApp?.bundleIdentifier ?? "unknown")")
                RecordingManager.shared.startRecording()
            }
        }

        // Escape → stop recording and inject transcription at cursor
        escapeHotKey = HotKey(key: .escape, modifiers: [])
        escapeHotKey?.keyDownHandler = {
            Task { @MainActor in
                guard AppState.shared.isRecording else { return }
                Logger.app.info("Escape: stopping recording, will inject text")
                RecordingManager.shared.stopRecording()
            }
        }

        Logger.app.info("Hotkeys registered: ⌃0 to start, Escape to stop + inject")
    }

    func unregister() {
        triggerHotKey = nil
        escapeHotKey = nil
    }
}
