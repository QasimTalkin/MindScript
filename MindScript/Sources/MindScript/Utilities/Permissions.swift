import AVFoundation
import AppKit
import ApplicationServices

enum Permissions {
    // MARK: - Microphone

    static var microphoneStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    // MARK: - Accessibility (needed for NSPasteboard+Cmd+V fallback injection)

    static var accessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    /// Clears the stale TCC entry and prompts macOS to re-register the current binary.
    /// Every rebuild produces a new binary hash — without resetting, the old hash stays
    /// trusted and AXIsProcessTrusted() returns false even with the toggle ON.
    static func requestAccessibility() {
        // Wipe the stale entry so macOS will register the current binary's hash.
        let reset = Process()
        reset.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        reset.arguments = ["reset", "Accessibility", "com.mindscript.app"]
        try? reset.run()
        reset.waitUntilExit()

        // Now prompt — this registers the current binary and shows the system dialog.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings > Privacy & Security > Microphone.
    static func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
