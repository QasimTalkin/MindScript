import Foundation
import AppKit

@Observable
final class AppState {
    static let shared = AppState()

    // Recording / transcription lifecycle
    var isRecording = false
    var isTranscribing = false
    var lastTranscription: String = ""
    var errorMessage: String? = nil

    // Auth
    var isSignedIn = false
    var userEmail: String? = nil
    var userTier: UserTier = .free

    // Metering
    var monthlySecondsUsed: Double = 0
    var isLimitReached: Bool {
        userTier == .free && monthlySecondsUsed >= Constants.freeMonthlyLimitSeconds
    }

    // Onboarding
    var hasCompletedOnboarding = false
    var isModelDownloaded = false
    var modelDownloadProgress: Double = 0

    private init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
}

enum UserTier: String, Codable {
    case free
    case pro
}
