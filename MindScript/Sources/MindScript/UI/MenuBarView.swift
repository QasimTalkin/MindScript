import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            statusSection
            Divider()
            if state.errorMessage == "monthly_limit_reached" {
                UpgradeView()
            } else {
                usageSection
            }
            Divider()
            footerActions
        }
        .frame(width: 300)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Image(systemName: "waveform.and.mic")
                .foregroundColor(.accentColor)
                .font(.title3)
            Text("MindScript")
                .font(.headline)
            Spacer()
            if state.userTier == .pro {
                Text("PRO")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if !state.lastTranscription.isEmpty {
                Text("\"\(state.lastTranscription.prefix(80))\(state.lastTranscription.count > 80 ? "…" : "")\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if let error = state.errorMessage, error != "monthly_limit_reached" {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if state.userTier == .free {
                let used = state.monthlySecondsUsed / 60
                let total = Constants.freeMonthlyLimitSeconds / 60
                let fraction = min(state.monthlySecondsUsed / Constants.freeMonthlyLimitSeconds, 1.0)

                HStack {
                    Text("Monthly usage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(used)) / \(Int(total)) min")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                ProgressView(value: fraction)
                    .tint(fraction > 0.8 ? .orange : .accentColor)
            } else {
                Label("Unlimited transcriptions", systemImage: "infinity")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var footerActions: some View {
        HStack {
            if state.isSignedIn {
                Text(state.userEmail ?? "Signed in")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            } else {
                Button("Sign In") {
                    // Open OnboardingView / auth sheet
                }
                .font(.caption)
                Spacer()
            }

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit MindScript")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        if state.isRecording { return .red }
        if state.isTranscribing { return .orange }
        if state.errorMessage != nil { return .yellow }
        return .green
    }

    private var statusText: String {
        if state.isRecording { return "Recording… (release ⌃0 to stop)" }
        if state.isTranscribing { return "Transcribing…" }
        if !state.isModelDownloaded {
            let pct = Int(state.modelDownloadProgress * 100)
            return "Downloading model… \(pct)%"
        }
        return "Ready — press ⌃0 to start"
    }
}
