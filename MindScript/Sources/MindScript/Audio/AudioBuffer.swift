import AVFoundation
import os

/// Converts AVAudioPCMBuffers into a 16 kHz mono WAV file for Whisper.
enum AudioBuffer {

    static func write(_ buffers: [AVAudioPCMBuffer], to url: URL) throws {
        guard !buffers.isEmpty else { throw AudioError.emptyBuffer }

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Constants.audioSampleRate,
            channels: Constants.audioChannelCount,
            interleaved: false
        ) else { throw AudioError.formatCreationFailed }

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

        let outputFile = try AVAudioFile(
            forWriting: url,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        if sourceFormat == targetFormat {
            for buffer in buffers { try outputFile.write(from: buffer) }
            return
        }

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

            var inputConsumed = false
            var conversionError: NSError?
            converter.convert(to: converted, error: &conversionError) { _, outStatus in
                if inputConsumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                outStatus.pointee = .haveData
                inputConsumed = true
                return buffer
            }
            if let err = conversionError { throw err }
            try outputFile.write(from: converted)
        }
    }

    static func temporaryURL() -> URL {
        let filename = "mindscript_\(Int(Date().timeIntervalSince1970)).wav"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
}

enum AudioError: LocalizedError {
    case emptyBuffer
    case formatCreationFailed
    case converterCreationFailed
    case bufferAllocationFailed

    var errorDescription: String? {
        switch self {
        case .emptyBuffer:            return "No audio was recorded."
        case .formatCreationFailed:   return "Could not create 16 kHz audio format."
        case .converterCreationFailed: return "Could not create audio format converter."
        case .bufferAllocationFailed: return "Could not allocate converted audio buffer."
        }
    }
}
