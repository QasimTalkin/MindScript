import AppKit
import AVFoundation
import os

/// Hotkey → record → stream-inject-at-cursor → done.
///
/// The recording overlay is non-activating so the target app stays focused
/// throughout. Every 1.2 s WhisperKit transcribes the growing audio buffer
/// and we inject only the NEW words (delta) at the cursor. On stop we inject
/// any remaining words and then dismiss the overlay.
@MainActor
final class Pipeline {
    static let shared = Pipeline()

    private var streamingTask: Task<Void, Never>?
    private var isChunkBusy = false
    private var injectedSoFar = ""
    private var lastStreamedText = ""

    private init() {}

    // MARK: - Startup

    func start() {
        Task {
            await downloadAndWarmModel()
            HotKeyManager.shared.register()
            if Permissions.accessibilityEnabled {
                AppState.shared.errorMessage = nil
            } else {
                AppState.shared.errorMessage = "needs_accessibility"
                NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
                // Poll silently — clears warning as soon as user grants access.
                await waitForAccessibility()
            }
            Logger.app.info("Pipeline ready")
        }
    }

    private func waitForAccessibility() async {
        while !Permissions.accessibilityEnabled {
            try? await Task.sleep(for: .seconds(2))
        }
        AppState.shared.errorMessage = nil
        NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
        Logger.app.info("Accessibility granted")
    }

    private func downloadAndWarmModel() async {
        do {
            AppState.shared.isModelDownloaded = false
            AppState.shared.modelDownloadProgress = 0
            NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
            try await TranscriptionService.shared.warmup()
            AppState.shared.isModelDownloaded = true
            AppState.shared.errorMessage = nil
            NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
        } catch {
            AppState.shared.errorMessage = "Model load failed: \(error.localizedDescription)"
            AppState.shared.isModelDownloaded = false
            NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
        }
    }

    // MARK: - Streaming

    func startStreaming() {
        injectedSoFar = ""
        lastStreamedText = ""
        isChunkBusy = false

        streamingTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(1.5))
            while AppState.shared.isRecording {
                await self.streamChunk()
                try? await Task.sleep(for: .seconds(1.2))
            }
        }
    }

    private func streamChunk() async {
        guard !isChunkBusy else { return }
        let snapshot = RecordingManager.shared.bufferSnapshot
        guard snapshot.count > 5 else { return }

        isChunkBusy = true
        defer { isChunkBusy = false }

        let url = AudioBuffer.temporaryURL()
        do {
            try AudioBuffer.write(snapshot, to: url)
            let lang = AppState.shared.transcriptionLanguage
            let partial = try await TranscriptionService.shared.transcribe(audioURL: url, language: lang)
            try? FileManager.default.removeItem(at: url)
            guard !partial.isEmpty else { return }

            lastStreamedText = partial
            AppState.shared.partialTranscription = partial
            injectDelta(fullText: partial)
        } catch {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func injectDelta(fullText: String) {
        let newWords = wordsAdded(from: injectedSoFar, to: fullText)
        guard !newWords.isEmpty else {
            injectedSoFar = fullText
            return
        }
        let toInject = injectedSoFar.isEmpty
            ? newWords.joined(separator: " ")
            : " " + newWords.joined(separator: " ")
        TextInjector.injectImmediate(text: toInject)
        injectedSoFar = fullText
    }

    private func wordsAdded(from prev: String, to next: String) -> [Substring] {
        let prevWords = prev.split(separator: " ", omittingEmptySubsequences: true)
        let nextWords = next.split(separator: " ", omittingEmptySubsequences: true)
        guard nextWords.count > prevWords.count else { return [] }
        return Array(nextWords[prevWords.count...])
    }

    // MARK: - Final

    func processAudio(buffers: [AVAudioPCMBuffer], duration: TimeInterval) async {
        streamingTask?.cancel()
        streamingTask = nil

        defer {
            AppState.shared.isTranscribing = false
            AppState.shared.partialTranscription = ""
            TranscriptionOverlay.shared.dismiss()
            NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
        }

        var finalText = ""
        let url = AudioBuffer.temporaryURL()
        do {
            try AudioBuffer.write(buffers, to: url)
            let lang = AppState.shared.transcriptionLanguage
            finalText = try await TranscriptionService.shared.transcribe(audioURL: url, language: lang)
            try? FileManager.default.removeItem(at: url)
        } catch {
            finalText = lastStreamedText
            Logger.app.error("Final transcription failed: \(error)")
        }

        lastStreamedText = ""
        guard !finalText.isEmpty else { return }

        let target = HotKeyManager.shared.capturedApp
        let remaining = wordsAdded(from: injectedSoFar, to: finalText)
        if !remaining.isEmpty {
            let toInject = injectedSoFar.isEmpty
                ? remaining.joined(separator: " ")
                : " " + remaining.joined(separator: " ")
            TextInjector.inject(text: toInject, into: target)
        } else if injectedSoFar.isEmpty {
            TextInjector.inject(text: finalText, into: target)
        }

        injectedSoFar = ""
        AppState.shared.lastTranscription = finalText
        _ = await MeteringService.shared.checkAndIncrement(durationSeconds: duration)
        Logger.app.info("Done: \"\(finalText.prefix(60))\"")

        // Summarisation — fire and forget; result lands in AppState.lastSummary
        if AppState.shared.summarizeNotesEnabled {
            Task {
                do {
                    _ = try await SummarisationService.shared.summarise(text: finalText)
                } catch {
                    AppState.shared.errorMessage = "Summary failed: \(error.localizedDescription)"
                    NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
                }
            }
        }
    }
}
