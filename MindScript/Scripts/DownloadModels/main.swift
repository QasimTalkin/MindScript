import WhisperKit
import Foundation


@main
struct DownloadModels {
    static func main() async {
        let models = ["openai_whisper-tiny", "openai_whisper-base"]

        // Same directory the app uses — repo-local, gitignored
        let here = URL(fileURLWithPath: #file)
        let modelsDir = here
            .deletingLastPathComponent()  // DownloadModels/
            .deletingLastPathComponent()  // Scripts/
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Models", isDirectory: true)

        print("==> Downloading models to: \(modelsDir.path)")

        for model in models {
            print("\n- \(model)...")
            do {
                try await WhisperKit.download(variant: model, downloadBase: modelsDir) { progress in
                    let pct = Int(progress.fractionCompleted * 100)
                    print("\r  \(pct)%", terminator: "")
                    fflush(stdout)
                }
                print("\n  [✓] done")
            } catch {
                print("\n  [✗] \(error.localizedDescription)")
            }
        }

        print("\n==> All done. Models are in \(modelsDir.path)")
    }
}
