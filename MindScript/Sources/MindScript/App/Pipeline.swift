import AppKit
import AVFoundation
import os

/// Full pipeline: hotkey → record → stream-inject-at-cursor → done.
///
/// How streaming injection works:
///   - The recording overlay is non-activating — the user's app stays focused throughout.
///   - Every 1.5s WhisperKit transcribes the growing audio buffer.
///   - We inject only the NEW words (delta) at the cursor, so text appears live as you speak.
///   - On stop, we inject any remaining delta (the last few words after the final chunk).
///   - No app-switching needed during recording, only a brief switch on final stop.
@MainActor
final class Pipeline {
    static let shared = Pipeline()

    private var streamingTask: Task<Void, Never>?
    private var isChunkBusy = false

    /// Tracks what we've already typed at the cursor so we only inject new words.
    private var injectedSoFar = ""
    private var lastStreamedText = ""

    private init() {}

    // MARK: - Startup

    func start() {
        Task {
            await downloadAndWarmModel()
            HotKeyManager.shared.register()
            // Note: Accessibility check is advisory only — injection is always attempted.
            // CGEventPost with .cgAnnotatedSessionEventTap works in most cases.
            if !Permissions.accessibilityEnabled {
                AppState.shared.errorMessage = "needs_accessibility"
                NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
            }
            Logger.app.info("Pipeline ready")
        }
    }

    private func downloadAndWarmModel() async {
        do {
            AppState.shared.isModelDownloaded = false
            NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
            try await TranscriptionService.shared.warmup()
            AppState.shared.isModelDownloaded = true
            AppState.shared.errorMessage = nil   // clear any stale error after model loads
            NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
        } catch {
            AppState.shared.errorMessage = "Model load failed: \(error.localizedDescription)"
            AppState.shared.isModelDownloaded = false
            NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
        }
    }

    // MARK: - Streaming (called by RecordingManager when recording starts)

    func startStreaming() {
        injectedSoFar = ""
        lastStreamedText = ""
        isChunkBusy = false

        streamingTask = Task { [weak self] in
            guard let self else { return }
            // Wait for the first chunk to have enough audio
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
        guard snapshot.count > 5 else { return }  // skip if almost no audio yet

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

            // Inject only the NEW part — delta since last injection
            injectDelta(fullText: partial)

        } catch {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Injects only the NEW words Whisper added since the last chunk.
    ///
    /// Uses word-count position rather than exact string prefix matching, so
    /// Whisper's mid-stream corrections to punctuation/capitalisation on earlier
    /// words don't block injection of the new words that follow them.
    private func injectDelta(fullText: String) {
        let newWords = wordsAdded(from: injectedSoFar, to: fullText)
        guard !newWords.isEmpty else {
            injectedSoFar = fullText   // keep tracking even if nothing new to inject
            return
        }
        // Prepend a space unless we haven't injected anything yet
        let toInject = injectedSoFar.isEmpty
            ? newWords.joined(separator: " ")
            : " " + newWords.joined(separator: " ")
        TextInjector.injectImmediate(text: toInject)
        injectedSoFar = fullText
    }

    /// Returns the words in `next` that come after position `prev.wordCount`.
    private func wordsAdded(from prev: String, to next: String) -> [Substring] {
        let prevWords = prev.split(separator: " ", omittingEmptySubsequences: true)
        let nextWords = next.split(separator: " ", omittingEmptySubsequences: true)
        guard nextWords.count > prevWords.count else { return [] }
        return Array(nextWords[prevWords.count...])
    }

    // MARK: - Final (called by RecordingManager when recording stops)

    func processAudio(buffers: [AVAudioPCMBuffer], duration: TimeInterval) async {
        streamingTask?.cancel()
        streamingTask = nil

        defer {
            AppState.shared.isTranscribing = false
            AppState.shared.partialTranscription = ""
            TranscriptionOverlay.shared.dismiss()
            NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
        }

        // Get the final transcription.
        // If streaming already has a result, do one more pass on the FULL buffer
        // to catch the last few words spoken before the user pressed stop.
        var finalText = ""

        let url = AudioBuffer.temporaryURL()
        do {
            try AudioBuffer.write(buffers, to: url)
            let lang = AppState.shared.transcriptionLanguage
            finalText = try await TranscriptionService.shared.transcribe(audioURL: url, language: lang)
            try? FileManager.default.removeItem(at: url)
        } catch {
            // Fall back to last streamed text if final transcription fails
            finalText = lastStreamedText
            Logger.app.error("Final transcription failed, using last streamed: \(error)")
        }

        lastStreamedText = ""
        guard !finalText.isEmpty else { return }

        // Always re-activate the captured app before final injection.
        // Pressing Escape can shift focus (e.g. closes a find-bar), so we
        // can't rely on the target app still being focused.
        let target = HotKeyManager.shared.capturedApp
        let remaining = wordsAdded(from: injectedSoFar, to: finalText)
        if !remaining.isEmpty {
            let toInject = injectedSoFar.isEmpty
                ? remaining.joined(separator: " ")
                : " " + remaining.joined(separator: " ")
            TextInjector.inject(text: toInject, into: target)
        } else if injectedSoFar.isEmpty {
            // Nothing was streamed — inject the full transcription
            TextInjector.inject(text: finalText, into: target)
        }

        injectedSoFar = ""
        AppState.shared.lastTranscription = finalText

        // Metering
        _ = await MeteringService.shared.checkAndIncrement(durationSeconds: duration)
        Logger.app.info("Done: \"\(finalText.prefix(60))\"")
    }
}
