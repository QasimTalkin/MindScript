import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var selectedModel: String = Constants.freeTierModelName

    // Binding-compatible wrapper for the @Observable language property
    private var languageBinding: Binding<String?> {
        Binding(
            get: { AppState.shared.transcriptionLanguage },
            set: { AppState.shared.transcriptionLanguage = $0 }
        )
    }

    var body: some View {
        Form {
            Section("Transcription") {
                Picker("Model", selection: $selectedModel) {
                    Text("Whisper Tiny (faster)").tag(Constants.freeTierModelName)
                    Text("Whisper Base (more accurate)")
                        .tag(Constants.proTierModelName)
                        .disabled(state.userTier != .pro)
                }
                .pickerStyle(.radioGroup)

                Picker("Language", selection: languageBinding) {
                    ForEach(Constants.supportedLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                Text("Auto-detect works well for most languages. Pin a language for faster, more accurate results when you always speak the same one.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Hotkey") {
                LabeledContent("Trigger", value: "⌃0  (Control + 0)")
                Text("Custom hotkey configuration coming in a future update.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Injection Method") {
                LabeledContent("Current method") {
                    Text(Permissions.accessibilityEnabled ? "Pasteboard (Cmd+V)" : "CGEvent (Unicode)")
                }
                if !Permissions.accessibilityEnabled {
                    Button("Enable Accessibility (more reliable)") {
                        Permissions.requestAccessibility()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("Updates") {
                Text("MindScript checks for updates automatically via Sparkle.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 500)
        .padding()
    }
}
