import WhisperKit
import Foundation
import os

/// Manages downloading and caching of Whisper models.
/// Models are stored in ~/Library/Application Support/MindScript/Models/
final class ModelManager {
    static let shared = ModelManager()

    private let modelsDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("MindScript/Models", isDirectory: true)
    }()

    private init() {
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }

    var modelName: String {
        AppState.shared.userTier == .pro ? Constants.proTierModelName : Constants.freeTierModelName
    }

    var isModelDownloaded: Bool {
        let modelPath = modelsDirectory.appendingPathComponent(modelName)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }

    /// Downloads the Whisper model appropriate for the current tier if not already cached.
    /// Calls `progress` on main thread with 0.0–1.0 values.
    func ensureModelDownloaded(progress: @escaping @MainActor (Double) -> Void) async throws {
        guard !isModelDownloaded else {
            await MainActor.run { progress(1.0) }
            return
        }

        Logger.transcription.info("Downloading model: \(self.modelName)")

        try await WhisperKit.download(
            variant: modelName,
            downloadBase: modelsDirectory.path,
            useBackgroundSession: false
        ) { p in
            Task { @MainActor in
                progress(p.fractionCompleted)
            }
        }

        Logger.transcription.info("Model download complete: \(self.modelName)")
    }
}
