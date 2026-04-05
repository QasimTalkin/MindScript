import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            statusSection
            Divider()
            modelSection
            Divider()
            languageSection
            Divider()
            footer
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

            if !state.isModelDownloaded {
                modelLoadingProgress
            }

            if !state.lastTranscription.isEmpty {
                Text("\"\(state.lastTranscription.prefix(80))\(state.lastTranscription.count > 80 ? "…" : "")\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if state.errorMessage == "needs_accessibility" {
                accessibilityPrompt
            } else if let error = state.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var modelSection: some View {
        HStack {
            Text("Model")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Picker("", selection: Binding(
                get: { state.selectedModel ?? (state.userTier == .pro ? Constants.proTierModelName : Constants.freeTierModelName) },
                set: { state.selectedModel = $0 }
            )) {
                Text("Whisper Tiny").tag(Constants.freeTierModelName)
                Text("Whisper Base").tag(Constants.proTierModelName)
            }
            .labelsHidden()
            .frame(width: 140)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var languageSection: some View {
        HStack {
            Text("Language")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Picker("", selection: Binding(
                get: { AppState.shared.transcriptionLanguage },
                set: { AppState.shared.transcriptionLanguage = $0 }
            )) {
                ForEach(Constants.supportedLanguages, id: \.code) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }
            .labelsHidden()
            .frame(width: 140)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var modelLoadingProgress: some View {
        let p = state.modelDownloadProgress
        let hasRealProgress = p >= 0.05   // HuggingFace CDN often omits Content-Length, so
                                           // fractionCompleted stays 0 until chunks arrive
        let pct = Int(p * 100)
        let phase: String = if p < 0.7 { "Downloading model…" }
                            else if p < 1.0 { "Loading into memory…" }
                            else { "Ready" }

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(phase)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if hasRealProgress {
                    Text("\(pct)%")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                } else {
                    // No granular data yet — show spinner instead of a lying "0%"
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 14, height: 14)
                }
            }
            if hasRealProgress {
                ProgressView(value: p)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            } else {
                // Indeterminate linear bar (animates automatically)
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
    }

    private var accessibilityPrompt: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Accessibility permission needed", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(.orange)
            Text("MindScript needs Accessibility access to type into other apps.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Open System Settings →") {
                Permissions.requestAccessibility()
                AppState.shared.errorMessage = nil
            }
            .font(.caption.weight(.medium))
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
        }
        .padding(8)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        HStack {
            Label("Unlimited — running locally", systemImage: "lock.open")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
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
        if !state.isModelDownloaded { return .yellow }
        if state.errorMessage != nil { return .yellow }
        return .green
    }

    private var statusText: String {
        if state.isRecording { return "Recording… press Esc to finish" }
        if state.isTranscribing { return "Transcribing…" }
        if !state.isModelDownloaded {
            return state.modelDownloadProgress < 0.7 ? "Downloading Whisper model…" : "Loading Whisper model…"
        }
        if state.errorMessage == "needs_accessibility" { return "Permission required" }
        return "Ready — press ⌃0 to start"
    }
}
