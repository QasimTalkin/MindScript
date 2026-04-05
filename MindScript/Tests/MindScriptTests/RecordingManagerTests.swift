import XCTest
import AVFoundation
@testable import MindScript

final class RecordingManagerTests: XCTestCase {
    func testWAVOutputIs16kHzMono() throws {
        // Build a synthetic 1-second 48kHz stereo buffer (typical mic input format)
        let sourceFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: 48_000)!
        buffer.frameLength = 48_000

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_output.wav")
        defer { try? FileManager.default.removeItem(at: url) }

        try AudioBuffer.write([buffer], to: url)

        let audioFile = try AVAudioFile(forReading: url)
        XCTAssertEqual(audioFile.fileFormat.sampleRate, 16_000, "Sample rate must be 16kHz for Whisper")
        XCTAssertEqual(audioFile.fileFormat.channelCount, 1, "Must be mono for Whisper")
    }

    func testEmptyBufferThrows() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("empty.wav")
        XCTAssertThrowsError(try AudioBuffer.write([], to: url)) { error in
            XCTAssertTrue(error is AudioError)
        }
    }

    func testTemporaryURLIsUnique() {
        let url1 = AudioBuffer.temporaryURL()
        Thread.sleep(forTimeInterval: 0.01)
        let url2 = AudioBuffer.temporaryURL()
        XCTAssertNotEqual(url1, url2)
    }
}
