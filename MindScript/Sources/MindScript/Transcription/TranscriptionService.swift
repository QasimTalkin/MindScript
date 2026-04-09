import WhisperKit
import Foundation
import os

/// Wraps WhisperKit with a single warm instance.
/// Models are cached in the local Models/ directory.
/// On first use of a model it is downloaded once; all subsequent launches load from disk.
actor TranscriptionService {
    static let shared = TranscriptionService()

    private var whisperKit: WhisperKit?
    private var loadedModelName: String?

    private init() {}

    // MARK: - Warmup

    /// Ensures the model is on disk (downloading once if needed), then loads it into memory.
    /// Subsequent calls for the same model return immediately.
    func warmup() async throws {
        let modelName = ModelManager.shared.modelName
        guard loadedModelName != modelName else { return }

        Logger.transcription.info("Warming up WhisperKit model: \(modelName)")

        await MainActor.run {
            AppState.shared.modelDownloadProgress = 0.02
            NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
        }

        // Phase 1 — download only if the model folder is not already on disk.
        let modelFolder = Constants.modelsDirectory
            .appendingPathComponent("models/argmaxinc/whisperkit-coreml/\(modelName)")

        if !FileManager.default.fileExists(atPath: modelFolder.path) {
            Logger.transcription.info("Model not cached — downloading \(modelName)")
            let downloadStartTime = Date()
            _ = try await WhisperKit.download(
                variant: modelName,
                downloadBase: Constants.modelsDirectory
            ) { progress in
                let reported = progress.fractionCompleted
                guard reported > 0.01 else { return }
                let fraction = max(0.02, min(reported, 1.0) * 0.65 + 0.02)
                let elapsed = Date().timeIntervalSince(downloadStartTime)
                let eta = elapsed > 2 ? formatDownloadETA((1.0 - reported) / (reported / elapsed)) : nil
                Task { @MainActor in
                    AppState.shared.modelDownloadProgress = fraction
                    AppState.shared.modelDownloadETA = eta
                    NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
                }
            }
            Logger.transcription.info("Download complete — model cached at \(modelFolder.path)")
        }

        await MainActor.run { AppState.shared.modelDownloadETA = nil }

        // Phase 2 — load from disk (0.7 → 1.0)
        await MainActor.run {
            AppState.shared.modelDownloadProgress = 0.7
            NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
        }

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
                case .loading:    0.5
                case .prewarming: 0.85
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

private func formatDownloadETA(_ seconds: Double) -> String {
    guard seconds > 0, seconds.isFinite else { return "" }
    let s = Int(seconds)
    if s < 60  { return "~\(s) sec" }
    let m = s / 60
    let r = s % 60
    if m >= 2  { return "~\(m) min" }
    return "~\(m) min \(r) sec"
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
