import Foundation
import os

/// Tracks which Whisper model variant to use based on the user's tier.
/// Model downloading and caching is handled by WhisperKit internally.
final class ModelManager {
    static let shared = ModelManager()

    private init() {}

    var modelName: String {
        AppState.shared.userTier == .pro ? Constants.proTierModelName : Constants.freeTierModelName
    }

    /// Called by Pipeline on startup. Progress goes 0.0 → 1.0 during WhisperKit init.
    /// Since WhisperKit handles the download itself, we just signal start/end here.
    func ensureModelDownloaded(progress: @escaping @MainActor (Double) -> Void) async throws {
        await MainActor.run { progress(0.05) }
        // Actual download + CoreML compilation happens inside TranscriptionService.warmup()
        // via WhisperKit(config). We'll update progress to 1.0 from Pipeline after warmup.
        await MainActor.run { progress(1.0) }
    }
}
