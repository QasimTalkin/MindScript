import AVFoundation
import os

/// Converts an array of AVAudioPCMBuffers into a single 16kHz mono WAV file
/// that is suitable for Whisper input.
enum AudioBuffer {
    static func write(_ buffers: [AVAudioPCMBuffer], to url: URL) throws {
        guard !buffers.isEmpty else {
            throw AudioError.emptyBuffer
        }

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Constants.audioSampleRate,
            channels: Constants.audioChannelCount,
            interleaved: false
        )!

        // If the buffers are already in the target format, write directly.
        // Otherwise, resample via AVAudioConverter.
        let sourceFormat = buffers[0].format

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: Constants.audioSampleRate,
            AVNumberOfChannelsKey: Constants.audioChannelCount,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: true,
        ]

        let outputFile = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)

        if sourceFormat == targetFormat {
            for buffer in buffers {
                try outputFile.write(from: buffer)
            }
        } else {
            guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
                throw AudioError.converterCreationFailed
            }

            for buffer in buffers {
                let frameCount = AVAudioFrameCount(
                    Double(buffer.frameLength) * Constants.audioSampleRate / sourceFormat.sampleRate
                )
                guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
                    throw AudioError.bufferAllocationFailed
                }

                var error: NSError?
                var inputConsumed = false

                converter.convert(to: converted, error: &error) { _, outStatus in
                    if inputConsumed {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    outStatus.pointee = .haveData
                    inputConsumed = true
                    return buffer
                }

                if let error { throw error }
                try outputFile.write(from: converted)
            }
        }

        Logger.recording.info("WAV written to \(url.path) — \(buffers.count) buffers")
    }

    static func temporaryURL() -> URL {
        let filename = "mindscript_\(Int(Date().timeIntervalSince1970)).wav"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
}

enum AudioError: LocalizedError {
    case emptyBuffer
    case converterCreationFailed
    case bufferAllocationFailed

    var errorDescription: String? {
        switch self {
        case .emptyBuffer: return "No audio was recorded."
        case .converterCreationFailed: return "Could not create audio format converter."
        case .bufferAllocationFailed: return "Could not allocate converted audio buffer."
        }
    }
}
