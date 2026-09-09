// The list prompt: pick one, or pick several.
//
// Driven entirely from the keyboard — arrows or j/k to move, ⌘1…9 to jump,
// type to filter once the list is long enough to need it, Enter to take the
// highlighted row. The mouse works too, but the keyboard is the design centre:
// this gets called from a terminal, by someone whose hands are already there.

import AppKit
import SwiftUI

struct ChooseView: View {
    @ObservedObject var coordinator: PromptCoordinator
    let spec: ChooseSpec

    @Environment(\.ui) private var ui
    @Environment(\.offscreenRendering) private var offscreenRendering
    @State private var cursor = 0
    @State private var checked: Set<Int> = []
    @State private var filterText = ""
    @FocusState private var filterFocused: Bool

    /// Beyond this many options a list is worth searching rather than scanning.
    private static let filterThreshold = 7
    /// Past this many rows the list scrolls instead of growing the panel.
    private static let rowsBeforeScrolling = 8
    /// Eight rows plus a peek at the ninth, so it is obvious there is more.
    private static let maximumListHeight: CGFloat = 330

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsFilter { filterField }
            list
            footer
        }
        .onAppear(perform: start)
        .onKeyDown(handle)
    }

    // ---- Data ----

    /// Positions in `spec.options` that survive the current filter, in order.
    private var visible: [Int] {
        let needle = filterText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return Array(spec.options.indices) }
        return spec.options.indices.filter { position in
            let option = spec.options[position]
            return option.value.lowercased().contains(needle)
                || (option.detail?.lowercased().contains(needle) ?? false)
        }
    }

    private var showsFilter: Bool {
        spec.forceFilter || spec.options.count > Self.filterThreshold
    }

    private var atLimit: Bool {
        guard let limit = spec.limit else { return false }
        return checked.count >= limit
    }

    // ---- Views ----

    private var filterField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(ui.palette.secondary.color)
            if offscreenRendering {
                Text(filterText.isEmpty ? "Filter" : filterText)
                    .font(ui.bodyFont)
                    .foregroundStyle(ui.palette.secondary.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("Filter", text: $filterText)
                    .textFieldStyle(.plain)
                    .font(ui.bodyFont)
                    .foregroundStyle(ui.palette.foreground.color)
                    .focused($filterFocused)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: ui.controlRadius, style: .continuous)
                .fill(ui.palette.surface.color)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ui.controlRadius, style: .continuous)
                .strokeBorder(ui.palette.border.color, lineWidth: ui.style.borderWidth))
    }

    @ViewBuilder private var list: some View {
        if visible.count > Self.rowsBeforeScrolling {
            ScrollViewReader { scroller in
                ScrollView(.vertical, showsIndicators: false) { rows }
                    .frame(maxHeight: Self.maximumListHeight)
                    .onChange(of: cursor) { _, position in
                        withAnimation(.easeOut(duration: 0.12)) {
                            scroller.scrollTo(position, anchor: .center)
                        }
                    }
            }
        } else {
            // A short list is just a stack — no ScrollView, and no
            // ScrollViewReader, which proposes the full available height to its
            // content and leaves a gap under a list shorter than the screen.
            rows
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(visible.enumerated()), id: \.element) { position, optionIndex in
                ChoiceRow(
                    option: spec.options[optionIndex],
                    isCursor: cursor == optionIndex,
                    isChecked: checked.contains(optionIndex),
                    showsCheckbox: spec.allowsMultiple,
                    shortcut: position < 9 ? position + 1 : nil,
                    isDimmed: spec.allowsMultiple && atLimit && !checked.contains(optionIndex)
                )
                .id(optionIndex)
                .onTapGesture { tap(optionIndex) }
                .onHover { hovering in
                    // Hover moves the cursor so that clicking and typing never
                    // disagree about which row is "current".
                    if hovering { cursor = optionIndex }
                }
            }
        }
        .padding(.vertical, 1)
    }

    private var footer: some View {
        PromptFooter(hints: hints) {
            if !coordinator.spec.insist {
                PromptButton(title: "Cancel") { coordinator.cancel() }
            }
            PromptButton(title: submitTitle, role: .primary, isFocused: true) { submit() }
        }
    }

    private var submitTitle: String {
        guard spec.allowsMultiple else { return "Select" }
        return checked.isEmpty ? "Select" : "Select \(checked.count)"
    }

    private var hints: [String] {
        var hints = ["↑↓ move"]
        if spec.allowsMultiple { hints.append("space toggle") }
        if showsFilter { hints.append("type to filter") }
        hints.append("↵ \(spec.allowsMultiple ? "done" : "select")")
        if !coordinator.spec.insist { hints.append("esc cancel") }
        return hints
    }

    // ---- Behaviour ----

    private func start() {
        checked = spec.preselected
        cursor = spec.preselected.min() ?? spec.options.indices.first ?? 0
        filterFocused = showsFilter
        coordinator.acceptCurrentState = currentSelection
    }

    /// What the current state means as an answer — also what `--on-timeout
    /// accept` submits.
    private func currentSelection() -> PromptOutcome {
        let indexes = spec.allowsMultiple ? checked.sorted() : [cursor]
        let values = indexes.compactMap {
            spec.options.indices.contains($0) ? spec.options[$0].value : nil
        }
        return .chosen(values: values, indexes: indexes)
    }

    private func tap(_ optionIndex: Int) {
        cursor = optionIndex
        guard spec.allowsMultiple else {
            // A click in a single-select list is the whole interaction; making
            // the user then press Enter would be a click too many.
            coordinator.finish(
                .chosen(
                    values: [spec.options[optionIndex].value],
                    indexes: [optionIndex]))
            return
        }
        toggle(optionIndex)
    }

    private func toggle(_ optionIndex: Int) {
        if checked.contains(optionIndex) {
            checked.remove(optionIndex)
        } else if !atLimit {
            checked.insert(optionIndex)
        }
    }

    private func submit() {
        if spec.allowsMultiple {
            coordinator.finish(
                .chosen(
                    values: checked.sorted().map { spec.options[$0].value },
                    indexes: checked.sorted()))
        } else {
            coordinator.finish(currentSelection())
        }
    }

    private func move(by offset: Int) {
        let rows = visible
        guard !rows.isEmpty else { return }
        let current = rows.firstIndex(of: cursor) ?? 0
        // Wraps, because a list you can fall off the end of is annoying at 2am.
        let next = (current + offset + rows.count) % rows.count
        cursor = rows[next]
    }

    private func handle(_ event: NSEvent) -> Bool {
        if Key.isCancel(event) {
            coordinator.cancel()
            return true
        }
        // ⌘1…9 jumps to a visible row and, in single-select, takes it.
        if event.modifierFlags.contains(.command),
            let digit = event.charactersIgnoringModifiers.flatMap({ Int($0) }),
            digit >= 1, digit <= 9
        {
            let rows = visible
            guard digit <= rows.count else { return true }
            tap(rows[digit - 1])
            return true
        }
        switch event.keyCode {
        case Key.arrowDown:
            move(by: 1)
            return true
        case Key.arrowUp:
            move(by: -1)
            return true
        case Key.space where spec.allowsMultiple && !filterFocused:
            toggle(cursor)
            return true
        default:
            break
        }
        if Key.isSubmit(event) {
            submit()
            return true
        }
        // j/k only when there is no filter field to type into — otherwise they
        // are just letters.
        if !showsFilter, let character = event.charactersIgnoringModifiers?.lowercased() {
            if character == "j" { move(by: 1); return true }
            if character == "k" { move(by: -1); return true }
        }
        return false
    }
}

/// One row. Knows nothing about selection logic — it is told how to look.
private struct ChoiceRow: View {
    @Environment(\.ui) private var ui
    let option: ChoiceOption
    let isCursor: Bool
    let isChecked: Bool
    let showsCheckbox: Bool
    /// The ⌘-digit that jumps here, if it has one.
    let shortcut: Int?
    /// True when --limit is reached and this row cannot be added.
    let isDimmed: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            if showsCheckbox {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13))
                    .foregroundStyle(checkboxColor)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(option.value)
                    .font(ui.bodyFont)
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                if let detail = option.detail {
                    Text(detail)
                        .font(ui.captionFont)
                        .foregroundStyle(secondaryColor)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let shortcut {
                Text("⌘\(shortcut)")
                    .font(ui.captionFont)
                    .foregroundStyle(secondaryColor.opacity(0.75))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ui.controlRadius, style: .continuous)
                .fill(isCursor ? ui.palette.accent.color : .clear)
        )
        .opacity(isDimmed ? 0.4 : 1)
        .contentShape(Rectangle())
    }

    // On the highlighted row everything sits on the accent colour, so it all
    // switches to the accent's foreground at once.
    private var primaryColor: Color {
        (isCursor ? ui.palette.accentForeground : ui.palette.foreground).color
    }

    private var secondaryColor: Color {
        isCursor ? ui.palette.accentForeground.opacity(0.75).color : ui.palette.secondary.color
    }

    private var checkboxColor: Color {
        if isCursor { return ui.palette.accentForeground.color }
        return (isChecked ? ui.palette.accent : ui.palette.secondary).color
    }
}
