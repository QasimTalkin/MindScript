import AppKit
import SwiftUI

@MainActor
final class TranscriptionOverlay {
    static let shared = TranscriptionOverlay()
    private var panel: NSPanel?
    private init() {}

    func show(state: OverlayState) {
        dismiss()
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: OverlayView(state: state))
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - 130
            let y = screen.visibleFrame.minY + 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.orderFront(nil)
        self.panel = panel
    }

    // No-op — text is now typed at cursor, not shown in the overlay
    func updateLiveText(_ text: String) {}

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

enum OverlayState { case recording, transcribing }

private struct OverlayView: View {
    let state: OverlayState

    var body: some View {
        HStack(spacing: 10) {
            if state == .recording {
                PulsingDot()
                VStack(alignment: .leading, spacing: 1) {
                    Text("Recording…")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Esc → finish & inject")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView().scaleEffect(0.75)
                Text("Finishing…")
                    .font(.system(size: 13, weight: .semibold))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial).shadow(radius: 8))
    }
}

private struct PulsingDot: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Circle().fill(Color.red.opacity(0.3))
                .frame(width: 16, height: 16)
                .scaleEffect(pulse ? 1.7 : 1)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
            Circle().fill(Color.red).frame(width: 8, height: 8)
        }
        .onAppear { pulse = true }
    }
}
