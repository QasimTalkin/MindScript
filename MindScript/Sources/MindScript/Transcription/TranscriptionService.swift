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
    /// WhisperKit downloads to ~/Library/Caches/huggingface automatically.
    /// Call once at startup; reuse the warm instance for all transcriptions.
    func warmup() async throws {
        let modelName = ModelManager.shared.modelName
        guard loadedModelName != modelName else { return }   // already warm

        Logger.transcription.info("Loading WhisperKit model: \(modelName)")

        // Don't pass modelFolder — let WhisperKit use its default cache location.
        // Passing a custom empty folder causes "file not found" errors.
        let config = WhisperKitConfig(
            model: modelName,
            verbose: false,
            logLevel: .error
        )

        whisperKit = try await WhisperKit(config)
        loadedModelName = modelName

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
            skipSpecialTokens: true
        )

        let results = try await whisperKit.transcribe(audioPath: audioURL.path, decodeOptions: options)
        let text = results
            .map { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        Logger.transcription.info("Transcribed: \"\(text.prefix(80))\"")
        return text
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
