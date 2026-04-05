import AVFoundation
import os

/// Manages mic capture via AVAudioEngine.
/// Taps the input node at 16kHz mono and accumulates PCM buffers.
/// On stop, writes a WAV file and notifies listeners via async continuation.
@MainActor
final class RecordingManager {
    static let shared = RecordingManager()

    private let engine = AVAudioEngine()
    private var buffers: [AVAudioPCMBuffer] = []
    private var recordingStartTime: Date?
    private var continuation: CheckedContinuation<URL, Error>?

    private init() {}

    // MARK: - Public API

    func startRecording() {
        guard !AppState.shared.isRecording else { return }

        Task {
            guard await Permissions.requestMicrophone() else {
                AppState.shared.errorMessage = "Microphone access denied. Enable it in System Settings → Privacy & Security → Microphone."
                notifyStateChange()
                return
            }
            do {
                try startEngine()
                AppState.shared.isRecording = true
                AppState.shared.errorMessage = nil
                recordingStartTime = Date()
                notifyStateChange()
                TranscriptionOverlay.shared.show(state: .recording)
                Logger.recording.info("Recording started")
            } catch {
                AppState.shared.errorMessage = error.localizedDescription
                notifyStateChange()
                Logger.recording.error("Failed to start recording: \(error)")
            }
        }
    }

    func stopRecording() {
        guard AppState.shared.isRecording else { return }
        AppState.shared.isRecording = false
        notifyStateChange()

        let captured = buffers
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        buffers = []
        recordingStartTime = nil

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        Logger.recording.info("Recording stopped — \(duration, format: .fixed(precision: 1))s, \(captured.count) buffers")

        TranscriptionOverlay.shared.show(state: .transcribing)
        AppState.shared.isTranscribing = true
        notifyStateChange()

        Task {
            await Pipeline.shared.processAudio(buffers: captured, duration: duration)
        }
    }

    // MARK: - Engine

    private func startEngine() throws {
        engine.reset()
        buffers = []

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // Request native format from the hardware, then convert to 16kHz in AudioBuffer.write()
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            Task { @MainActor in
                self.buffers.append(buffer)
            }
        }

        try engine.start()
    }

    private func notifyStateChange() {
        NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
    }
}
