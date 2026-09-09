// The yes/no prompt.
//
// The whole point is that it exits 0 or 1, so the interaction is kept to one
// decision: two buttons, one of them focused, Enter takes the focused one.
// y and n work too, because they always have.

import AppKit
import SwiftUI

struct ConfirmView: View {
    @ObservedObject var coordinator: PromptCoordinator
    let spec: ConfirmSpec

    @Environment(\.ui) private var ui
    @State private var yesFocused = true

    var body: some View {
        PromptFooter(hints: hints) {
            PromptButton(
                title: spec.negative,
                role: .secondary,
                isFocused: !yesFocused
            ) {
                coordinator.finish(.confirmed(false))
            }
            PromptButton(
                title: spec.affirmative,
                role: spec.destructive ? .destructive : .primary,
                isFocused: yesFocused
            ) {
                coordinator.finish(.confirmed(true))
            }
        }
        .onAppear(perform: start)
        .onKeyDown(handle)
    }

    private var hints: [String] {
        var hints = ["←→ choose", "↵ confirm", "y / n"]
        if !coordinator.spec.insist { hints.append("esc cancel") }
        return hints
    }

    private func start() {
        yesFocused = spec.defaultsToYes
        // A timeout that accepts takes the focused button — which is the one
        // --default-no exists to change.
        coordinator.acceptCurrentState = { .confirmed(yesFocused) }
    }

    private func handle(_ event: NSEvent) -> Bool {
        if Key.isCancel(event) {
            coordinator.cancel()
            return true
        }
        switch event.keyCode {
        case Key.arrowLeft, Key.arrowRight, Key.tab:
            yesFocused.toggle()
            return true
        default:
            break
        }
        if Key.isSubmit(event) {
            coordinator.finish(.confirmed(yesFocused))
            return true
        }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "y":
            coordinator.finish(.confirmed(true))
            return true
        case "n":
            coordinator.finish(.confirmed(false))
            return true
        default:
            return false
        }
    }
}
