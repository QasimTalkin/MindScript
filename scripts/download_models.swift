import Foundation
import WhisperKit

@main
struct DownloadModels {
    static func main() async {
        let models = ["openai_whisper-tiny", "openai_whisper-base", "openai_whisper-small"]
        print("==> Pre-downloading Whisper models...")
        
        for model in models {
            print("\n- Downloading \(model)...")
            do {
                try await WhisperKit.download(variant: model) { progress in
                    let percent = Int(progress.fractionCompleted * 100)
                    print("\r  Progress: \(percent)%", terminator: "")
                    fflush(stdout)
                }
                print("\n  [✓] \(model) ready.")
            } catch {
                print("\n  [✗] Failed to download \(model): \(error.localizedDescription)")
            }
        }
        
        print("\n==> All downloads complete. Models are stored in ~/Library/Caches/huggingface/hub")
    }
}
