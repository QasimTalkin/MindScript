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
        if name.contains("tiny")         { return "Whisper Tiny" }
        if name.contains("base")         { return "Whisper Base" }
        if name.contains("distil-small") { return "Distil Small (EN)" }
        return name
    }

    var isLanguageFixed: Bool {
        let name = selectedModel ?? (userTier == .pro ? Constants.proTierModelName : Constants.freeTierModelName)
        return name.contains("distil") && name.contains(".en")
    }

    // Summarisation
    var summarizeNotesEnabled = false {
        didSet { UserDefaults.standard.set(summarizeNotesEnabled, forKey: "summarizeNotesEnabled") }
    }
    var isSummarizing = false
    var lastSummary: String = ""
    var summarizationProviderType: AISummarisationProviderType = .ollama {
        didSet { UserDefaults.standard.set(summarizationProviderType.rawValue, forKey: "summarizationProviderType") }
    }
    var summarizationModel: String = Constants.defaultSummarisationModel {
        didSet { UserDefaults.standard.set(summarizationModel, forKey: "summarizationModel") }
    }
    var summarizationApiKey: String? {
        didSet { UserDefaults.standard.set(summarizationApiKey, forKey: "summarizationApiKey") }
    }

    // Live audio metering — updated from RecordingManager tap
    var audioLevel: Float = 0

    // Onboarding
    var hasCompletedOnboarding = false
    var isModelDownloaded = false
    var modelDownloadProgress: Double = 0

    private init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        transcriptionLanguage = UserDefaults.standard.string(forKey: "transcriptionLanguage")
        selectedModel = UserDefaults.standard.string(forKey: "selectedModel")
        // Summarisation — restore persisted values
        summarizeNotesEnabled = UserDefaults.standard.bool(forKey: "summarizeNotesEnabled")
        if let raw = UserDefaults.standard.string(forKey: "summarizationProviderType"),
           let type = AISummarisationProviderType(rawValue: raw) {
            summarizationProviderType = type
        }
        if let m = UserDefaults.standard.string(forKey: "summarizationModel") { summarizationModel = m }
        summarizationApiKey = UserDefaults.standard.string(forKey: "summarizationApiKey")
    }
}

enum UserTier: String, Codable {
    case free
    case pro
}
