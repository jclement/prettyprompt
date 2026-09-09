// Showing a prompt and getting an answer back.
//
// This is the only place that runs an event loop. `present` blocks the calling
// command until the user answers, the timeout fires, or the prompt is
// cancelled, then returns — so every subcommand reads as straight-line code.

import AppKit
import SwiftUI

enum PromptPresenter {
    /// Opens the prompt and blocks until it is answered. Main thread only.
    static func present(_ spec: PromptSpec) -> PromptOutcome {
        let application = NSApplication.shared
        // .accessory keeps prettyprompt out of the Dock and the ⌘-Tab switcher
        // while still allowing it to take keyboard focus — the same policy
        // Spotlight-style launchers use.
        application.setActivationPolicy(.accessory)

        let coordinator = PromptCoordinator(spec: spec)
        let controller = NSHostingController(rootView: PromptRootView(coordinator: coordinator))
        controller.sizingOptions = [.preferredContentSize]

        let panel = PromptPanel.make(contentViewController: controller)
        panel.delegate = coordinator
        panel.onCancel = { coordinator.cancel() }
        panel.appearance = chromeAppearance(for: spec.theme)
        coordinator.panel = panel

        panel.setContentSize(controller.view.fittingSize)
        panel.centre(on: spec.screen)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        if spec.sound { NSSound.beep() }

        coordinator.startTimeoutIfNeeded()
        application.run()
        return coordinator.outcome
    }

    /// The appearance the panel's blur and any system controls should adopt.
    ///
    /// Themes that follow the system return nil so SwiftUI's colorScheme flows
    /// through untouched; fixed themes pin it to match their own background, so
    /// a light theme never gets a dark frosted backdrop behind it.
    private static func chromeAppearance(for theme: Theme) -> NSAppearance? {
        guard theme.appearance != .system else { return nil }
        let palette = theme.palette(systemIsDark: theme.appearance == .dark)
        return NSAppearance(named: palette.isDarkBackground ? .darkAqua : .aqua)
    }
}

/// Owns the answer, the countdown and the window's lifetime.
///
/// Views talk to this rather than to AppKit: they call `finish` with an
/// outcome, or `cancel`, and never touch the panel.
final class PromptCoordinator: NSObject, ObservableObject, NSWindowDelegate {
    let spec: PromptSpec

    /// Seconds left on `--timeout`, or nil when there is no timeout. Published
    /// so the countdown bar can draw itself.
    @Published private(set) var secondsRemaining: TimeInterval?

    /// Defaults to cancelled: if the process is killed or the loop exits any
    /// way other than through `finish`, the shell sees a cancellation rather
    /// than a bogus success.
    private(set) var outcome: PromptOutcome = .cancelled

    weak var panel: PromptPanel?

    /// Set by whichever view is on screen. Called when `--on-timeout accept`
    /// fires, to turn the current selection or text into an answer.
    var acceptCurrentState: (() -> PromptOutcome)?

    private var countdown: Timer?
    /// Guards against a second answer arriving after the first — a timeout
    /// firing in the same tick as a click, for instance.
    private var hasFinished = false

    init(spec: PromptSpec) {
        self.spec = spec
    }

    /// Ends the prompt with an answer and unblocks `present`.
    func finish(_ outcome: PromptOutcome) {
        guard !hasFinished else { return }
        hasFinished = true
        self.outcome = outcome
        stopTimeout()
        panel?.orderOut(nil)

        NSApp.stop(nil)
        // -stop only takes effect once another event is dequeued, so give the
        // loop something to dequeue. Without this the app hangs until the user
        // moves the mouse.
        if let wakeUp = NSEvent.otherEvent(
            with: .applicationDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 0,
            data1: 0,
            data2: 0)
        {
            NSApp.postEvent(wakeUp, atStart: true)
        }
    }

    /// Esc, or any other request to give up. Ignored entirely under `--insist`.
    func cancel() {
        guard !spec.insist else { return }
        finish(.cancelled)
    }

    // ---- Timeout ----

    func startTimeoutIfNeeded() {
        guard let timeout = spec.timeout else { return }
        let end = Date().addingTimeInterval(timeout)
        secondsRemaining = timeout

        // A tenth of a second is fine enough for a smooth bar and coarse enough
        // to cost nothing over the minutes a long timeout might run.
        countdown = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let left = end.timeIntervalSinceNow
            self.secondsRemaining = max(0, left)
            guard left <= 0 else { return }
            // `accept` submits whatever is on screen; `cancel` prints nothing
            // and exits 124.
            switch self.spec.timeoutBehaviour {
            case .cancel: self.finish(.timedOut)
            case .accept: self.finish(self.acceptCurrentState?() ?? .timedOut)
            }
        }
    }

    private func stopTimeout() {
        countdown?.invalidate()
        countdown = nil
        secondsRemaining = nil
    }

    /// Fraction of the timeout still to run, 1 down to 0. Nil without a timeout.
    var timeoutFraction: Double? {
        guard let secondsRemaining, let timeout = spec.timeout, timeout > 0 else { return nil }
        return min(1, max(0, secondsRemaining / timeout))
    }

    // ---- NSWindowDelegate ----

    /// The panel grows and shrinks as the filter narrows a list, so it is
    /// re-centred on every resize. Otherwise it would creep down the screen.
    func windowDidResize(_ notification: Notification) {
        panel?.centre(on: spec.screen)
    }
}
