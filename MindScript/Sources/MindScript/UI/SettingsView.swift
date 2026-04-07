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
                Picker("Whisper Model", selection: Binding(
                    get: { state.selectedModel ?? (state.userTier == .pro ? Constants.proTierModelName : Constants.freeTierModelName) },
                    set: { state.selectedModel = $0 }
                )) {
                    Text("Whisper Tiny (faster)").tag(Constants.freeTierModelName)
                    Text("Whisper Base (accurate)").tag(Constants.proTierModelName)
                    Text("Distil Small (EN only)").tag(Constants.distilSmallModelName)
                }
                .pickerStyle(.radioGroup)

                Picker("Language", selection: languageBinding) {
                    ForEach(Constants.supportedLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .disabled(state.isLanguageFixed)

                if state.isLanguageFixed {
                    Text("The selected Distil model is optimized for English only.")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("Auto-detect works well for most languages. Pin a language for faster, more accurate results when you always speak the same one.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("AI Summarisation") {
                Toggle("Enable Auto-summarize", isOn: Binding(
                    get: { state.summarizeNotesEnabled },
                    set: { state.summarizeNotesEnabled = $0 }
                ))
                
                Picker("Provider", selection: Binding(
                    get: { state.summarizationProviderType },
                    set: { val in
                        state.summarizationProviderType = val
                        state.summarizationModel = val.defaultModel
                    }
                )) {
                    ForEach(AISummarisationProviderType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                TextField("Model", text: Binding(
                    get: { state.summarizationModel },
                    set: { state.summarizationModel = $0 }
                ))
                
                if state.summarizationProviderType.requiresApiKey {
                    SecureField("API Key", text: Binding(
                        get: { state.summarizationApiKey ?? "" },
                        set: { state.summarizationApiKey = $0 }
                    ))
                }
                
                Text("Summaries are generated locally via Ollama by default. You can also use OpenAI or Anthropic by providing an API key.")
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
