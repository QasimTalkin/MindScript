import AVFoundation
import AppKit

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

    /// Opens System Settings → Privacy & Security → Accessibility.
    /// Only call this when the user explicitly clicks a button — never call automatically.
    static func requestAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens System Settings > Privacy & Security > Microphone.
    static func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
