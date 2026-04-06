import WhisperKit
import Foundation
import os

/// Wraps WhisperKit with a single warm instance.
/// WhisperKit manages its own model download/cache location automatically.
/// We do NOT pass a custom modelFolder — that would require models to already be compiled.
actor TranscriptionService {
    static let shared = TranscriptionService()

    private var whisperKit: WhisperKit?
    private var loadedModelName: String?

    private init() {}

    // MARK: - Warmup

    /// Loads (and downloads if needed) the Whisper model.
    /// Reports progress to AppState.modelDownloadProgress (0.0 – 1.0):
    ///   0–70%  = download phase
    ///   70–100% = model-load phase
    func warmup() async throws {
        let modelName = ModelManager.shared.modelName
        guard loadedModelName != modelName else { return }   // already warm

        Logger.transcription.info("Loading WhisperKit model: \(modelName)")

        // Seed a nonzero value immediately so the bar doesn't stick at 0%
        await MainActor.run {
            AppState.shared.modelDownloadProgress = 0.02
            NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
        }

        // Phase 1: download (0.02 → 0.7)
        // Note: HuggingFace Hub SDK reports fractionCompleted only once total size is known,
        // so it often fires at 0. We clamp to at least 0.02 and force to 0.7 after it returns.
        let modelFolder = try await WhisperKit.download(
            variant: modelName,
            downloadBase: Constants.modelsDirectory
        ) { progress in
            let reported = progress.fractionCompleted
            guard reported > 0.01 else { return }  // skip spurious 0% callbacks
            let fraction = max(0.02, min(reported, 1.0) * 0.68 + 0.02)
            Task { @MainActor in
                AppState.shared.modelDownloadProgress = fraction
                NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
            }
        }

        // Download done (cached or freshly downloaded) — advance to load phase
        await MainActor.run {
            AppState.shared.modelDownloadProgress = 0.7
            NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
        }

        // Phase 2: load (0.7 → 1.0)
        // Init with load: false so we can attach the callback before loading starts.
        let kit = try await WhisperKit(WhisperKitConfig(
            model: modelName,
            modelFolder: modelFolder.path,
            verbose: false,
            logLevel: .error,
            prewarm: false,
            load: false,
            download: false
        ))

        kit.modelStateCallback = { _, newState in
            let fraction: Double = switch newState {
                case .loading:    0.75
                case .prewarming: 0.90
                case .loaded:     1.0
                default:          AppState.shared.modelDownloadProgress
            }
            Task { @MainActor in
                AppState.shared.modelDownloadProgress = fraction
                NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
            }
        }

        try await kit.loadModels()

        whisperKit = kit
        loadedModelName = modelName

        await MainActor.run {
            AppState.shared.modelDownloadProgress = 1.0
        }
        Logger.transcription.info("WhisperKit ready — model: \(modelName)")
    }

    // MARK: - Transcribe

    func transcribe(audioURL: URL, language: String? = nil) async throws -> String {
        guard let whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        let options = DecodingOptions(
            task: .transcribe,
            language: language,         // nil = auto-detect
            temperature: 0.0,
            temperatureFallbackCount: 5,
            sampleLength: 224,
            topK: 5,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            noSpeechThreshold: 0.3     // suppress silent/noise-only segments
        )

        let results = try await whisperKit.transcribe(audioPath: audioURL.path, decodeOptions: options)
        let text = results
            .map { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .removingWhisperHallucinations()

        Logger.transcription.info("Transcribed: \"\(text.prefix(80))\"")
        return text
    }
}

private extension String {
    /// Strips tokens Whisper hallucinates on silence/noise instead of returning empty text.
    func removingWhisperHallucinations() -> String {
        let hallucinations: [String] = [
            "[BLANK_AUDIO]", "[BLANK AUDIO]",
            "[ Silence ]", "[Silence]", "(silence)",
            "[INAUDIBLE]", "(inaudible)",
            "[noise]", "[Noise]", "(noise)",
            "[music]", "[Music]", "(music)",
        ]
        var result = self
        for token in hallucinations {
            result = result.replacingOccurrences(of: token, with: "", options: .caseInsensitive)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "Model not loaded yet — please wait a moment."
        }
    }
}
