import AppKit
import SwiftUI

enum OverlayState {
    case recording
    case transcribing
}

/// A small floating HUD that shows recording / transcribing state.
/// Appears near the bottom of the screen, non-activating.
@MainActor
final class TranscriptionOverlay {
    static let shared = TranscriptionOverlay()

    private var panel: NSPanel?

    private init() {}

    func show(state: OverlayState) {
        dismiss()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 48),
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

        let hostingView = NSHostingView(rootView: OverlayView(state: state))
        panel.contentView = hostingView

        // Position: bottom-center of the main screen
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - 110
            let y = screen.visibleFrame.minY + 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct OverlayView: View {
    let state: OverlayState

    var body: some View {
        HStack(spacing: 10) {
            if state == .recording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.4), lineWidth: 4)
                            .scaleEffect(1.5)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: state == .recording)
                    )
                Text("Recording…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            } else {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Transcribing…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(radius: 8)
        )
    }
}
