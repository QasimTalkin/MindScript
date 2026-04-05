import SwiftUI

struct UpgradeView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.badge.plus")
                .font(.largeTitle)
                .foregroundColor(.accentColor)

            Text("You've hit your free limit")
                .font(.headline)

            Text("Upgrade to MindScript Pro for unlimited transcriptions and a more accurate model.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: openUpgradeURL) {
                Text("Upgrade to Pro — $8/mo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            Button("Maybe later") {}
                .font(.caption)
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
        }
        .padding()
    }

    private func openUpgradeURL() {
        guard let url = URL(string: Constants.stripeProMonthlyURL) else { return }
        NSWorkspace.shared.open(url)
    }
}
