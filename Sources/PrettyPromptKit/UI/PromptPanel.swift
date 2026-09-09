// The window itself, and where it goes.
//
// Three things have to be true for a prompt launched from a shell script to
// work: it must take keyboard focus (a borderless NSPanel refuses to become key
// unless you say otherwise), it must float above whatever is already on screen
// including full-screen apps, and it must land on the display the user is
// actually looking at. Each of those is one deliberate line below.

import AppKit

final class PromptPanel: NSPanel {
    /// Borderless windows are not key-eligible by default, which would leave
    /// the text field un-typeable. This is the single most important override
    /// in the app.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Esc reaches the panel as `cancelOperation`. AppKit's default is to close
    /// the window, which would bypass the outcome bookkeeping entirely, so the
    /// coordinator gets it instead — and never sees it under `--insist`.
    var onCancel: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    /// Builds the panel with the float-above-everything behaviour configured.
    static func make(contentViewController: NSViewController) -> PromptPanel {
        let panel = PromptPanel(
            contentRect: .zero,
            // .nonactivatingPanel is deliberately absent: we want activation.
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)

        panel.contentViewController = contentViewController
        panel.isFloatingPanel = true
        // .modalPanel outranks ordinary floating windows and full-screen app
        // content, which is what "forced on top" has to mean to be useful.
        panel.level = .modalPanel
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        // Survives the user clicking away — a prompt that vanishes when you
        // glance at another window is worse than no prompt.
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true

        // The panel is drawn entirely by SwiftUI — rounded corners, border and
        // shadow alike — so the window contributes nothing at all.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // AppKit's own window shadow is derived from the content's opacity and
        // gets it wrong for a translucent rounded panel, painting a hard grey
        // rectangle behind it. The theme's shadow is drawn in SwiftUI instead.
        panel.hasShadow = false

        panel.animationBehavior = .utilityWindow
        return panel
    }

    /// Puts the panel dead centre of the chosen display.
    ///
    /// Centred on the *visible* frame rather than the full frame, so the menu
    /// bar and Dock don't push the optical centre off.
    func centre(on choice: ScreenChoice) {
        guard let screen = ScreenPlacement.screen(for: choice) else { return }
        let area = screen.visibleFrame
        let origin = NSPoint(
            x: area.midX - frame.width / 2,
            y: area.midY - frame.height / 2)
        setFrameOrigin(NSPoint(x: origin.x.rounded(), y: origin.y.rounded()))
    }
}

enum ScreenPlacement {
    /// Resolves a `--screen` choice to an actual display.
    ///
    /// `.mouse` is the default because the pointer is the best available proxy
    /// for "the screen you are looking at" — better than the focused window,
    /// which on a multi-display desk is often the one you just walked away from.
    static func screen(for choice: ScreenChoice) -> NSScreen? {
        switch choice {
        case .mouse:
            let pointer = NSEvent.mouseLocation
            return NSScreen.screens.first { $0.frame.contains(pointer) }
                ?? NSScreen.main
                ?? NSScreen.screens.first
        case .focused:
            return NSScreen.main ?? NSScreen.screens.first
        case let .index(position):
            let screens = NSScreen.screens
            guard position < screens.count else { return NSScreen.main ?? screens.first }
            return screens[position]
        }
    }
}
