import AppKit
import SwiftUI

@MainActor
final class TranscriptionOverlay {
    static let shared = TranscriptionOverlay()
    private var panel: NSPanel?
    private init() {}

    func show(state: OverlayState) {
        if let existing = panel {
            (existing.contentView as? NSHostingView<OverlayRootView>)?.rootView = OverlayRootView(state: state)
            return
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 96),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false          // shadow is drawn inside SwiftUI
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: OverlayRootView(state: state))
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - 210
            let y = screen.visibleFrame.minY + 36
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.orderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        AppState.shared.audioLevel = 0
    }
}

enum OverlayState { case recording, transcribing }

// Root wrapper so we can swap state without recreating the panel
struct OverlayRootView: View {
    let state: OverlayState
    var body: some View {
        ZStack {
            if state == .recording {
                RecordingPill()
            } else {
                TranscribingPill()
            }
        }
        .frame(width: 420, height: 96)
    }
}

// MARK: - Recording pill

private struct RecordingPill: View {
    // Rolling window of audio levels (newest on the right)
    @State private var levels: [Float] = Array(repeating: 0, count: 44)
    private let ticker = Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 16) {
            // Left — pulsing record dot
            PulsingDot()

            // Centre — live waveform
            WaveformBars(levels: levels)
                .frame(maxWidth: .infinity)
                .frame(height: 44)

            // Right — escape hint
            VStack(alignment: .center, spacing: 2) {
                Text("esc")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                Text("inject")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.09))
                .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 10)
        )
        .padding(16) // room for shadow
        .onReceive(ticker) { _ in
            let raw = AppState.shared.audioLevel
            // Smooth + amplify: quiet audio should still show visible bars
            let amplified = Swift.min(raw * 12, 1.0)
            levels.removeFirst()
            levels.append(amplified)
        }
    }
}

// MARK: - Waveform bars

private struct WaveformBars: View {
    let levels: [Float]

    private let barW: CGFloat   = 3
    private let spacing: CGFloat = 2
    private let minH: CGFloat   = 3
    private let maxH: CGFloat   = 40

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(0..<levels.count, id: \.self) { i in
                let h = Swift.max(minH, Swift.min(CGFloat(levels[i]) * maxH, maxH))
                // Older bars (left) fade out slightly
                let alpha = 0.35 + 0.65 * Double(i) / Double(levels.count)
                RoundedRectangle(cornerRadius: barW / 2)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1, green: 0.25, blue: 0.25), Color.red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .opacity(alpha)
                    )
                    .frame(width: barW, height: h)
                    .animation(.spring(response: 0.12, dampingFraction: 0.65), value: levels[i])
            }
        }
    }
}

// MARK: - Transcribing pill

private struct TranscribingPill: View {
    @State private var phase: Int = 0
    private let ticker = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 14) {
            // Three bouncing dots
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.75))
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase % 3 == i ? 1.45 : 0.75)
                        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: phase)
                }
            }
            Text("Transcribing…")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, 22)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.09))
                .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 10)
        )
        .padding(16)
        .onReceive(ticker) { _ in phase += 1 }
    }
}

// MARK: - Pulsing dot

private struct PulsingDot: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.22))
                .frame(width: 22, height: 22)
                .scaleEffect(pulse ? 1.7 : 1.0)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
        }
        .onAppear { pulse = true }
    }
}
