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

    /// Opens System Settings > Privacy > Accessibility with a prompt.
    static func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings > Privacy & Security > Microphone.
    static func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
