import AppKit
import os

/// Orchestrates the full hotkey → record → transcribe → meter → inject pipeline.
@MainActor
final class Pipeline {
    static let shared = Pipeline()

    private init() {}

    // MARK: - Startup

    func start() {
        Task {
            // Download model if needed, then warm up WhisperKit
            await downloadAndWarmModel()

            // Register the global hotkey last — only after the model is ready
            HotKeyManager.shared.register()
            Logger.app.info("Pipeline ready")
        }
    }

    private func downloadAndWarmModel() async {
        do {
            try await ModelManager.shared.ensureModelDownloaded { progress in
                AppState.shared.modelDownloadProgress = progress
                if progress >= 1.0 {
                    AppState.shared.isModelDownloaded = true
                }
            }
            try await TranscriptionService.shared.warmup()
        } catch {
            AppState.shared.errorMessage = "Model load failed: \(error.localizedDescription)"
            Logger.app.error("Model warmup failed: \(error)")
        }
    }

    // MARK: - Audio processing (called by RecordingManager)

    func processAudio(buffers: [AVAudioPCMBuffer], duration: TimeInterval) async {
        defer {
            AppState.shared.isTranscribing = false
            TranscriptionOverlay.shared.dismiss()
            NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
        }

        // 1. Write WAV
        let audioURL = AudioBuffer.temporaryURL()
        do {
            try AudioBuffer.write(buffers, to: audioURL)
        } catch {
            AppState.shared.errorMessage = error.localizedDescription
            Logger.app.error("Audio write failed: \(error)")
            return
        }

        // 2. Transcribe (on-device, free)
        let text: String
        do {
            text = try await TranscriptionService.shared.transcribe(audioURL: audioURL)
        } catch {
            AppState.shared.errorMessage = error.localizedDescription
            Logger.app.error("Transcription failed: \(error)")
            return
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: audioURL)

        guard !text.isEmpty else {
            Logger.app.info("Empty transcription — nothing to inject")
            return
        }

        // 3. Metering check (after transcription so no network latency on the hot path)
        let allowed = await MeteringService.shared.checkAndIncrement(durationSeconds: duration)
        guard allowed else {
            AppState.shared.errorMessage = nil
            await MainActor.run {
                // Show upgrade prompt — implemented in UpgradeView via AppState observation
                AppState.shared.errorMessage = "monthly_limit_reached"
            }
            Logger.metering.info("Free tier limit reached — injection blocked")
            return
        }

        // 4. Inject
        AppState.shared.lastTranscription = text
        let targetApp = HotKeyManager.shared.capturedApp
        TextInjector.inject(text: text, into: targetApp)
    }
}
