import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var stateObserverTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        Pipeline.shared.start()

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

    func applicationWillTerminate(_ notification: Notification) {
        stateObserverTask?.cancel()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "MindScript")
        button.image?.isTemplate = true
        button.action = #selector(togglePopover)
        button.target = self

        stateObserverTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .mindscriptStateChanged) {
                self?.updateStatusIcon()
            }
        }
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        let state = AppState.shared
        let symbolName: String
        if state.isRecording {
            symbolName = "record.circle.fill"
        } else if state.isTranscribing {
            symbolName = "waveform"
        } else if state.errorMessage != nil {
            symbolName = "exclamationmark.circle"
        } else {
            symbolName = "mic"
        }
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MindScript")
        button.image?.isTemplate = true
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView().environment(AppState.shared)
        )
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    // MARK: - URL scheme (mindscript://upgrade-success)

    @objc private func handleURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent _: NSAppleEventDescriptor
    ) {
        guard
            let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString),
            url.host == "upgrade-success"
        else { return }

        Task {
            await AuthManager.shared.refreshProfile()
            await MeteringService.shared.syncFromServer()
        }
    }
}

extension Notification.Name {
    static let mindscriptStateChanged = Notification.Name("mindscriptStateChanged")
}
