import AppKit
import SwiftUI
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var updaterController: SPUStandardUpdaterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("DEBUG: applicationDidFinishLaunching")
        // Menubar-only: no Dock icon, no app switcher entry
        NSApp.setActivationPolicy(.accessory)

        // Don't start Sparkle auto-updater in local dev builds (placeholder feed URL would crash)
        // setupSparkle()
        print("DEBUG: calling setupStatusItem")
        setupStatusItem()
        print("DEBUG: calling setupPopover")
        setupPopover()
        print("DEBUG: calling setupPipeline")
        setupPipeline()

        // Handle mindscript:// URL scheme (e.g. mindscript://upgrade-success)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        if !AppState.shared.hasCompletedOnboarding {
            showPopover()
        }
    }

    // MARK: - Setup

    private func setupSparkle() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else {
            print("DEBUG: statusItem.button is nil — status item creation failed")
            return
        }
        print("DEBUG: statusItem.button exists, setting image")
        button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "MindScript")
        button.image?.isTemplate = true
        button.action = #selector(togglePopover)
        button.target = self
        updateStatusIcon()

        // Observe state changes to update icon
        Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(named: .mindscriptStateChanged) {
                self.updateStatusIcon()
            }
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environment(AppState.shared)
        )
    }

    private func setupPipeline() {
        // Wire up the full transcription pipeline
        Pipeline.shared.start()
    }

    // MARK: - Status icon

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        let state = AppState.shared
        if state.isRecording {
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
        } else if state.isTranscribing {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Transcribing")
        } else if state.errorMessage != nil {
            button.image = NSImage(systemSymbolName: "exclamationmark.circle", accessibilityDescription: "Error")
        } else {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "MindScript")
        }
        button.image?.isTemplate = true
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    // MARK: - URL scheme handler

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent _: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else { return }

        if url.host == "upgrade-success" {
            Task {
                await AuthManager.shared.refreshProfile()
                await MeteringService.shared.syncFromServer()
            }
        }
    }
}

extension Notification.Name {
    static let mindscriptStateChanged = Notification.Name("mindscriptStateChanged")
}
