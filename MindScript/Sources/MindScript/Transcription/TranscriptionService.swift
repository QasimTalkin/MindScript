import WhisperKit
import Foundation
import os

/// Wraps WhisperKit with a single warm instance.
/// The instance is initialized once at app start and reused for all transcriptions.
actor TranscriptionService {
    static let shared = TranscriptionService()

    private var whisperKit: WhisperKit?
    private var loadedModelName: String?

    private init() {}

    // MARK: - Warmup

    /// Must be called once at startup (or after a model switch) to load the model into memory.
    func warmup() async throws {
        let modelName = ModelManager.shared.modelName
        guard loadedModelName != modelName else { return }   // already warm

        Logger.transcription.info("Warming up WhisperKit with model: \(modelName)")

        let modelDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("MindScript/Models/\(modelName)").path

        let config = WhisperKitConfig(
            model: modelName,
            modelFolder: modelDirectory,
            verbose: false,
            logLevel: .error
        )

        whisperKit = try await WhisperKit(config)
        loadedModelName = modelName

        Logger.transcription.info("WhisperKit warm — model: \(modelName)")
    }

    // MARK: - Transcribe

    /// Transcribes the audio at `audioURL` and returns the trimmed text.
    func transcribe(audioURL: URL) async throws -> String {
        guard let whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        let options = DecodingOptions(
            language: nil,          // auto-detect language
            task: .transcribe,
            temperature: 0.0,
            temperatureFallbackCount: 5,
            sampleLength: 224,
            topK: 5,
            usePrefillPrompt: true,
            skipSpecialTokens: true
        )

        let results = try await whisperKit.transcribe(audioPath: audioURL.path, decodeOptions: options)
        let text = results.compactMap { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        Logger.transcription.info("Transcribed: \"\(text.prefix(80))\"")
        return text
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "Whisper model is not loaded. Please wait for the model to finish downloading."
        }
    }
}
