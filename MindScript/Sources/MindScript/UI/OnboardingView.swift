import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @State private var step: OnboardingStep = .welcome
    @State private var email = ""
    @State private var isSendingLink = false
    @State private var linkSent = false
    @State private var errorText: String?

    enum OnboardingStep {
        case welcome, microphone, model, account, done
    }

    var body: some View {
        VStack(spacing: 20) {
            switch step {
            case .welcome:
                welcomeStep
            case .microphone:
                microphoneStep
            case .model:
                modelStep
            case .account:
                accountStep
            case .done:
                doneStep
            }
        }
        .padding(24)
        .frame(width: 340)
        .animation(.easeInOut, value: step)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Welcome to MindScript")
                .font(.title2.bold())
            Text("Press **⌃0** anywhere to start transcribing. Your words appear instantly at the cursor.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Get Started") { step = .microphone }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private var microphoneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            Text("Microphone Access")
                .font(.title3.bold())
            Text("MindScript needs microphone access to capture your voice. Your audio is processed entirely on your device.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Allow Microphone Access") {
                Task {
                    let granted = await Permissions.requestMicrophone()
                    if granted { step = .model }
                    else { Permissions.openMicrophoneSettings() }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var modelStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            Text("Downloading AI Model")
                .font(.title3.bold())
            Text("Whisper Tiny (~75 MB) runs fully on your device. This is a one-time download.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            if state.isModelDownloaded {
                Label("Model ready", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Button("Continue") { step = .account }
                    .buttonStyle(.borderedProminent)
            } else {
                ProgressView(value: state.modelDownloadProgress)
                    .padding(.horizontal)
                Text("\(Int(state.modelDownloadProgress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .onChange(of: state.isModelDownloaded) { _, downloaded in
            if downloaded { step = .account }
        }
    }

    private var accountStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            Text("Create an Account")
                .font(.title3.bold())
            Text("Track your usage and unlock Pro features. Free for your first 60 min/month.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            TextField("your@email.com", text: $email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)

            if let error = errorText {
                Text(error).font(.caption).foregroundColor(.red)
            }

            if linkSent {
                Label("Magic link sent — check your email", systemImage: "envelope.badge")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Button(linkSent ? "Resend link" : "Send Magic Link") {
                sendMagicLink()
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || isSendingLink)

            Button("Skip for now") { finishOnboarding() }
                .font(.caption)
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
        }
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("You're all set!")
                .font(.title2.bold())
            Text("Press **⌃0** anywhere to start dictating. The text will appear at your cursor.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Start Using MindScript") { finishOnboarding() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    // MARK: - Actions

    private func sendMagicLink() {
        isSendingLink = true
        errorText = nil
        Task {
            do {
                try await AuthManager.shared.signInWithEmail(email)
                linkSent = true
            } catch {
                errorText = error.localizedDescription
            }
            isSendingLink = false
        }
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        AppState.shared.hasCompletedOnboarding = true
    }
}
