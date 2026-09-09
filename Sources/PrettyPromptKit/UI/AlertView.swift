// The one-button prompt.
//
// Not a question — an interruption. `make || prettyprompt alert "Build failed"`.
// It still honours --insist, which for an alert means the script gets proof the
// message was actually seen.

import AppKit
import SwiftUI

struct AlertView: View {
    @ObservedObject var coordinator: PromptCoordinator
    let buttonLabel: String

    var body: some View {
        PromptFooter(hints: hints) {
            PromptButton(title: buttonLabel, role: .primary, isFocused: true) {
                coordinator.finish(.acknowledged)
            }
        }
        .onAppear {
            // An alert has no state to preserve; a timeout that "accepts" it is
            // the same as being dismissed.
            coordinator.acceptCurrentState = { .acknowledged }
        }
        .onKeyDown(handle)
    }

    private var hints: [String] {
        coordinator.spec.insist ? ["↵ dismiss"] : ["↵ dismiss", "esc cancel"]
    }

    private func handle(_ event: NSEvent) -> Bool {
        if Key.isCancel(event) {
            coordinator.cancel()
            return true
        }
        guard Key.isSubmit(event) || event.keyCode == Key.space else { return false }
        coordinator.finish(.acknowledged)
        return true
    }
}
