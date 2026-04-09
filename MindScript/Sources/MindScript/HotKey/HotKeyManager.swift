import AppKit
import HotKey
import os

/// Manages the global hotkeys for MindScript.
///
/// Three-key flow:
/// - Press ⌥0     → start recording (captures the frontmost app at this moment)
/// - Press ⌥Space → pause / resume recording
/// - Press ⌥Esc   → stop recording, transcribe, inject text at cursor
@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var triggerHotKey: HotKey?
    private var escapeHotKey: HotKey?
    private var pauseHotKey: HotKey?

    /// The app that was focused when the user pressed ⌃0 to start recording.
    private(set) var capturedApp: NSRunningApplication?

    private init() {}

    func register() {
        // Option+0 → start recording only (ignored if already recording)
        triggerHotKey = HotKey(key: .zero, modifiers: .option)
        triggerHotKey?.keyDownHandler = { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard !AppState.shared.isRecording else { return }
                // Capture the app the user was working in before we do anything
                self.capturedApp = NSWorkspace.shared.frontmostApplication
                Logger.app.info("⌥0: starting recording, target=\(self.capturedApp?.bundleIdentifier ?? "unknown")")
                RecordingManager.shared.startRecording()
            }
        }

        // Option+Space → pause / resume recording (only active during a recording session)
        pauseHotKey = HotKey(key: .space, modifiers: .option)
        pauseHotKey?.keyDownHandler = {
            Task { @MainActor in
                guard AppState.shared.isRecording else { return }
                if AppState.shared.isPaused {
                    Logger.app.info("⌥Space: resuming recording")
                    RecordingManager.shared.resumeRecording()
                } else {
                    Logger.app.info("⌥Space: pausing recording")
                    RecordingManager.shared.pauseRecording()
                }
            }
        }

        // Option+Escape → stop recording and inject transcription at cursor
        escapeHotKey = HotKey(key: .escape, modifiers: .option)
        escapeHotKey?.keyDownHandler = {
            Task { @MainActor in
                guard AppState.shared.isRecording else { return }
                Logger.app.info("⌥Esc: stopping recording, will inject text")
                RecordingManager.shared.stopRecording()
            }
        }

        Logger.app.info("Hotkeys registered: ⌥0 to start, ⌥Space to pause/resume, ⌥Esc to stop + inject")
    }

    func unregister() {
        triggerHotKey = nil
        pauseHotKey = nil
        escapeHotKey = nil
    }
}
