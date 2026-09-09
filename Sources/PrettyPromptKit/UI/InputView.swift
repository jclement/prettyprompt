// The text prompt.
//
// One field, focused the moment the panel appears, so that `prettyprompt input
// "Branch name?"` is a thing you can answer without touching the mouse.

import AppKit
import SwiftUI

struct InputView: View {
    @ObservedObject var coordinator: PromptCoordinator
    let spec: InputSpec

    @Environment(\.ui) private var ui
    @Environment(\.offscreenRendering) private var offscreenRendering
    @State private var text = ""
    @FocusState private var fieldFocused: Bool

    /// Tall enough for a commit message without being a document editor.
    private static let multilineHeight: CGFloat = 116

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            field
            footer
        }
        .onAppear(perform: start)
        .onKeyDown(handle)
    }

    @ViewBuilder private var field: some View {
        Group {
            if offscreenRendering {
                // Gallery rendering: AppKit text controls cannot draw here.
                Text(text.isEmpty ? (spec.placeholder ?? "") : text)
                    .font(ui.bodyFont)
                    .foregroundStyle(
                        (text.isEmpty ? ui.palette.secondary : ui.palette.foreground).color
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: spec.multiline ? Self.multilineHeight : nil)
            } else if spec.multiline {
                TextEditor(text: $text)
                    .font(ui.bodyFont)
                    .foregroundStyle(ui.palette.foreground.color)
                    .scrollContentBackground(.hidden)
                    .frame(height: Self.multilineHeight)
                    .focused($fieldFocused)
            } else if spec.secure {
                SecureField(spec.placeholder ?? "", text: $text)
                    .textFieldStyle(.plain)
                    .font(ui.bodyFont)
                    .foregroundStyle(ui.palette.foreground.color)
                    .focused($fieldFocused)
                    .onSubmit(submit)
            } else {
                TextField(spec.placeholder ?? "", text: $text)
                    .textFieldStyle(.plain)
                    .font(ui.bodyFont)
                    .foregroundStyle(ui.palette.foreground.color)
                    .focused($fieldFocused)
                    .onSubmit(submit)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, spec.multiline ? 7 : 10)
        .background(
            RoundedRectangle(cornerRadius: ui.controlRadius, style: .continuous)
                .fill(ui.palette.surface.color)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ui.controlRadius, style: .continuous)
                .strokeBorder(
                    fieldFocused ? ui.palette.accent.color : ui.palette.border.color,
                    lineWidth: fieldFocused ? 2 : ui.style.borderWidth))
    }

    private var footer: some View {
        PromptFooter(hints: hints) {
            if !coordinator.spec.insist {
                PromptButton(title: "Cancel") { coordinator.cancel() }
            }
            PromptButton(title: "OK", role: .primary, isFocused: true, action: submit)
                .opacity(canSubmit ? 1 : 0.45)
                .allowsHitTesting(canSubmit)
        }
    }

    private var hints: [String] {
        var hints: [String] = []
        hints.append(spec.multiline ? "⌘↵ submit" : "↵ submit")
        if !coordinator.spec.insist { hints.append("esc cancel") }
        if spec.requiresValue && !canSubmit { hints.append("required") }
        return hints
    }

    private var canSubmit: Bool {
        !spec.requiresValue || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func start() {
        text = spec.initialValue
        fieldFocused = true
        coordinator.acceptCurrentState = { .text(text) }
    }

    private func submit() {
        guard canSubmit else { return }
        coordinator.finish(.text(text))
    }

    private func handle(_ event: NSEvent) -> Bool {
        if Key.isCancel(event) {
            coordinator.cancel()
            return true
        }
        guard Key.isSubmit(event) else { return false }
        // In a text area Enter belongs to the text; ⌘↩ is the submit gesture,
        // the same as everywhere else on the platform.
        if spec.multiline && !event.modifierFlags.contains(.command) { return false }
        submit()
        return true
    }
}
