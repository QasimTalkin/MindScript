import AVFoundation
import Accelerate
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

    /// A snapshot of the audio captured so far — safe to read while recording continues.
    var bufferSnapshot: [AVAudioPCMBuffer] { buffers }

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
                AppState.shared.partialTranscription = ""
                recordingStartTime = Date()
                notifyStateChange()
                TranscriptionOverlay.shared.show(state: .recording)
                Pipeline.shared.startStreaming()
                Logger.recording.info("Recording started")
            } catch {
                AppState.shared.errorMessage = error.localizedDescription
                notifyStateChange()
                Logger.recording.error("Failed to start recording: \(error)")
            }
        }
    }

    /// Stop recording and kick off transcription.
    func stopRecording() {
        guard AppState.shared.isRecording else { return }
        stopEngine()

        let captured = buffers
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        buffers = []
        recordingStartTime = nil

        Logger.recording.info("Recording stopped — \(duration, format: .fixed(precision: 1))s")

        TranscriptionOverlay.shared.show(state: .transcribing)
        AppState.shared.isTranscribing = true
        notifyStateChange()

        Task {
            await Pipeline.shared.processAudio(buffers: captured, duration: duration)
        }
    }

    /// Cancel recording — discard audio, no transcription.
    func cancelRecording() {
        guard AppState.shared.isRecording else { return }
        stopEngine()
        buffers = []
        recordingStartTime = nil
        TranscriptionOverlay.shared.dismiss()
        Logger.recording.info("Recording cancelled")
    }

    // MARK: - Engine

    private func stopEngine() {
        AppState.shared.isRecording = false
        notifyStateChange()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private func startEngine() throws {
        engine.reset()
        buffers = []

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // Request native format from the hardware, then convert to 16kHz in AudioBuffer.write()
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let level = Self.rms(buffer: buffer)
            Task { @MainActor in
                self.buffers.append(buffer)
                AppState.shared.audioLevel = level
            }
        }

        try engine.start()
    }

    private func notifyStateChange() {
        NotificationCenter.default.post(name: .mindscriptStateChanged, object: nil)
    }

    private static func rms(buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let count = vDSP_Length(buffer.frameLength)
        guard count > 0 else { return 0 }
        var result: Float = 0
        vDSP_rmsqv(data, 1, &result, count)
        return result
    }
}
