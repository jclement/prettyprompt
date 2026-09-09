// Keyboard handling that actually fires.
//
// SwiftUI on macOS gives you .onExitCommand and focus-dependent key handling,
// neither of which is reliable enough for a prompt whose entire job is to be
// driven from the keyboard. A local event monitor sees every key press in this
// process before anything else does, which makes shortcuts like ⌘↩ and
// type-to-filter work regardless of which control holds focus.

import AppKit
import SwiftUI

extension View {
    /// Runs `handler` for every key press while this view is on screen.
    /// Return true to consume the event and stop it reaching the focused
    /// control; false to let it through.
    func onKeyDown(_ handler: @escaping (NSEvent) -> Bool) -> some View {
        background(KeyMonitorView(handler: handler).frame(width: 0, height: 0))
    }
}

private struct KeyMonitorView: NSViewRepresentable {
    let handler: (NSEvent) -> Bool

    func makeNSView(context: Context) -> NSView {
        context.coordinator.start()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.handler = handler
    }

    func makeCoordinator() -> Coordinator { Coordinator(handler: handler) }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var handler: (NSEvent) -> Bool
        private var monitor: Any?

        init(handler: @escaping (NSEvent) -> Bool) {
            self.handler = handler
        }

        func start() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handler(event) ? nil : event
            }
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit { stop() }
    }
}

/// The key codes prettyprompt cares about, named.
enum Key {
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let escape: UInt16 = 53
    static let space: UInt16 = 49
    static let tab: UInt16 = 48
    static let arrowLeft: UInt16 = 123
    static let arrowRight: UInt16 = 124
    static let arrowDown: UInt16 = 125
    static let arrowUp: UInt16 = 126

    static func isSubmit(_ event: NSEvent) -> Bool {
        event.keyCode == returnKey || event.keyCode == keypadEnter
    }

    /// Esc, or ⌘. — the two things a Mac user reaches for to back out.
    /// Every prompt view checks this first, so that `--insist` has exactly one
    /// place to be honoured.
    static func isCancel(_ event: NSEvent) -> Bool {
        if event.keyCode == escape { return true }
        return event.modifierFlags.contains(.command)
            && event.charactersIgnoringModifiers == "."
    }
}
