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
            summarisationSection
            if state.lastSummary != "" || state.isSummarizing {
                Divider()
                summaryPanel
            }
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
                Text("Distil Small (EN)").tag(Constants.distilSmallModelName)
            }
            .labelsHidden()
            .frame(width: 140)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var summarisationSection: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundColor(.accentColor)
                .font(.caption)
            Text("Auto-summarize")
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: Binding(
                get: { state.summarizeNotesEnabled },
                set: { state.summarizeNotesEnabled = $0 }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SUMMARY")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                Spacer()
                if state.isSummarizing {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                } else {
                    Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(state.lastSummary, forType: .string) }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .help("Copy summary")
                }
            }
            
            if state.isSummarizing && state.lastSummary.isEmpty {
                Text("Thinking…")
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.secondary)
            } else {
                Text(state.lastSummary)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .lineLimit(6)
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.05))
    }

    private var languageSection: some View {
        HStack {
            Text("Language")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if state.isLanguageFixed {
                Text("English (Fixed)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 8)
            } else {
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
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var modelLoadingProgress: some View {
        let p = state.modelDownloadProgress
        let pct = Int(p * 100)
        let isDownloading = p < 0.7
        let phase = isDownloading ? "Downloading model…" : "Loading into memory…"

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(phase)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if p >= 0.05 {
                    HStack(spacing: 3) {
                        Text("\(pct)%")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                        if let eta = state.modelDownloadETA, isDownloading {
                            Text("·")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(eta)
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                } else {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 14, height: 14)
                }
            }
            if p >= 0.05 {
                ProgressView(value: p)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            } else {
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
