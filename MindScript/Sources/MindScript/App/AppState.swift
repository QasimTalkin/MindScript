import Foundation
import AppKit

@Observable
final class AppState {
    static let shared = AppState()

    // Recording / transcription lifecycle
    var isRecording = false
    var isTranscribing = false
    var lastTranscription: String = ""
    var partialTranscription: String = ""   // live text shown while recording
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

    // Language — nil = Whisper auto-detect
    var transcriptionLanguage: String? {
        didSet { UserDefaults.standard.set(transcriptionLanguage, forKey: "transcriptionLanguage") }
    }

    // Model selection — nil defaults to tier-based base/tiny
    var selectedModel: String? {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "selectedModel")
            // Trigger a warmup if the model changed
            Task {
                try? await TranscriptionService.shared.warmup()
            }
        }
    }

    var currentModelDisplayName: String {
        let name = selectedModel ?? (userTier == .pro ? Constants.proTierModelName : Constants.freeTierModelName)
        if name.contains("tiny") { return "Whisper Tiny" }
        if name.contains("base") { return "Whisper Base" }
        return name
    }

    // Onboarding
    var hasCompletedOnboarding = false
    var isModelDownloaded = false
    var modelDownloadProgress: Double = 0

    private init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        transcriptionLanguage = UserDefaults.standard.string(forKey: "transcriptionLanguage")
        selectedModel = UserDefaults.standard.string(forKey: "selectedModel")
    }
}

enum UserTier: String, Codable {
    case free
    case pro
}
