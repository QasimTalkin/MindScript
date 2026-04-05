import Foundation

/// Returns the Whisper model variant to use based on the user's tier.
/// Downloading and CoreML compilation are handled by WhisperKit internally.
final class ModelManager {
    static let shared = ModelManager()
    private init() {}

    var modelName: String {
        AppState.shared.userTier == .pro ? Constants.proTierModelName : Constants.freeTierModelName
    }
}
