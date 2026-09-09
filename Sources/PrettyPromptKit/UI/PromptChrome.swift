// The panel shell every prompt is drawn inside, plus the themed controls the
// individual prompts assemble.
//
// Layout is identical across all four prompt kinds — icon and title, an
// optional message, the prompt's own content, then a footer of key hints and
// buttons. Only the content differs. Keeping the shell here is what makes a new
// theme apply everywhere at once, and what stops the four prompts drifting into
// four slightly different dialogs.

import SwiftUI

// ---- Theme plumbing ----

/// The resolved look for this run, handed down the view tree so no component
/// has to be passed a Theme.
struct ThemeContext {
    let palette: Palette
    let style: Style

    // Type scale. Only the title is theme-controlled; the rest is fixed so that
    // a theme can change personality without breaking the layout.
    var titleFont: Font {
        .system(
            size: style.titleSize, weight: style.titleWeight.weight, design: style.fontFamily.design
        )
    }
    var bodyFont: Font { .system(size: 13, weight: .regular, design: style.fontFamily.design) }
    var controlFont: Font { .system(size: 13, weight: .medium, design: style.fontFamily.design) }
    var captionFont: Font { .system(size: 11, weight: .regular, design: style.fontFamily.design) }

    /// Controls sit slightly tighter than the panel so they read as nested.
    var controlRadius: CGFloat { max(0, min(10, style.cornerRadius * 0.55)) }
}

private struct ThemeContextKey: EnvironmentKey {
    static let defaultValue = ThemeContext(palette: BuiltInThemes.auto.dark, style: Style())
}

private struct OffscreenRenderingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var ui: ThemeContext {
        get { self[ThemeContextKey.self] }
        set { self[ThemeContextKey.self] = newValue }
    }

    /// True while the view tree is being drawn by ImageRenderer rather than
    /// shown in a window. AppKit-backed views draw as a "not supported" glyph
    /// there, so the blur substitutes a flat tint.
    var offscreenRendering: Bool {
        get { self[OffscreenRenderingKey.self] }
        set { self[OffscreenRenderingKey.self] = newValue }
    }
}

// ---- Root ----

/// Chooses the palette for the current appearance and picks the right prompt
/// view for the spec.
struct PromptRootView: View {
    @ObservedObject var coordinator: PromptCoordinator
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let spec = coordinator.spec
        let context = ThemeContext(
            palette: spec.theme.palette(systemIsDark: colorScheme == .dark),
            style: spec.theme.style)

        PromptChrome(coordinator: coordinator) {
            switch spec.kind {
            case let .choose(choose):
                ChooseView(coordinator: coordinator, spec: choose)
            case let .input(input):
                InputView(coordinator: coordinator, spec: input)
            case let .confirm(confirm):
                ConfirmView(coordinator: coordinator, spec: confirm)
            case let .alert(buttonLabel):
                AlertView(coordinator: coordinator, buttonLabel: buttonLabel)
            }
        }
        .environment(\.ui, context)
        .frame(width: spec.width)
    }
}

/// Icon, title, message, content, and the draining timeout bar.
struct PromptChrome<Content: View>: View {
    @ObservedObject var coordinator: PromptCoordinator
    @Environment(\.ui) private var ui
    @Environment(\.offscreenRendering) private var offscreenRendering
    @ViewBuilder var content: Content

    /// Breathing room on all four sides. Generous enough that the panel reads as
    /// a considered object rather than a system alert.
    private let inset: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hazardBand
            header
            content
                .padding(.horizontal, inset)
                .padding(.bottom, inset)
            hazardBand
            timeoutBar
        }
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: ui.style.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ui.style.cornerRadius, style: .continuous)
                .strokeBorder(ui.palette.border.color, lineWidth: ui.style.borderWidth)
        )
        .shadow(
            color: .black.opacity(ui.style.shadowOpacity),
            radius: ui.style.shadowRadius, y: ui.style.shadowRadius / 4
        )
        // The shadow is drawn inside the window, so the window has to be bigger
        // than the panel by the shadow's reach or it gets clipped.
        .padding(ui.style.shadowRadius / 2 + 6)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon = coordinator.spec.icon {
                PromptIcon(name: icon)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(ui.titleFont)
                    .tracking(ui.style.uppercaseTitle ? 1.2 : 0)
                    .foregroundStyle(ui.palette.foreground.color)
                    .fixedSize(horizontal: false, vertical: true)
                if let message = coordinator.spec.message, !message.isEmpty {
                    // Markdown, so a prompt can emphasise the part that matters
                    // and list what is about to happen.
                    RichText(source: message)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, inset)
        .padding(.top, inset)
        .padding(.bottom, 16)
    }

    private var titleText: String {
        ui.style.uppercaseTitle
            ? coordinator.spec.title.uppercased()
            : coordinator.spec.title
    }

    @ViewBuilder private var background: some View {
        ZStack {
            if ui.style.material && !offscreenRendering {
                VisualEffectBackground(cornerRadius: ui.style.cornerRadius)
            }
            ui.palette.background.color
        }
    }

    /// Caution tape, for themes that ask for it. Top and bottom, so the panel
    /// is recognisable as the serious one from the corner of your eye.
    @ViewBuilder private var hazardBand: some View {
        if ui.style.hazardStripes {
            HazardStripes(
                bright: ui.palette.foreground.color,
                dark: ui.palette.background.color
            )
            .frame(height: 10)
        }
    }

    /// A hairline that drains left to right as `--timeout` runs down. Absent
    /// when there is no timeout, so it never draws attention to nothing.
    @ViewBuilder private var timeoutBar: some View {
        if let fraction = coordinator.timeoutFraction {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    ui.palette.secondary.opacity(0.15).color
                    // Runs from accent to danger as the time goes, so urgency is
                    // visible without reading a number.
                    (fraction < 0.25 ? ui.palette.danger : ui.palette.accent).color
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 3)
            .animation(.linear(duration: 0.1), value: fraction)
        }
    }
}

/// An emoji, or an SF Symbol when the string names one.
struct PromptIcon: View {
    @Environment(\.ui) private var ui
    let name: String

    var body: some View {
        Group {
            if NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil {
                Image(systemName: name)
                    .font(.system(size: ui.style.titleSize + 2))
                    .foregroundStyle(ui.palette.accent.color)
            } else {
                // Anything that isn't a symbol name is drawn as text, which is
                // exactly right for an emoji and harmless for a typo.
                Text(name).font(.system(size: ui.style.titleSize + 2))
            }
        }
        .frame(width: ui.style.titleSize + 6, alignment: .center)
    }
}

// ---- Controls ----

/// The three button roles a prompt can need.
enum ButtonRole {
    /// Filled with the accent colour; what Enter does.
    case primary
    /// Outlined; the way out.
    case secondary
    /// Filled with the danger colour; used for `confirm --destructive`.
    case destructive
}

struct PromptButton: View {
    @Environment(\.ui) private var ui
    let title: String
    var role: ButtonRole = .secondary
    /// Draws the focus ring. Exactly one button in a footer should have it.
    var isFocused: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(ui.style.uppercaseTitle ? title.uppercased() : title)
                .font(ui.controlFont)
                .tracking(ui.style.uppercaseTitle ? 0.8 : 0)
                .foregroundStyle(foreground)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .frame(minWidth: 78)
                .background(
                    RoundedRectangle(cornerRadius: ui.controlRadius, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ui.controlRadius, style: .continuous)
                        .strokeBorder(border, lineWidth: ui.style.borderWidth)
                )
                .overlay(focusRing)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var accent: ThemeColor {
        role == .destructive ? ui.palette.danger : ui.palette.accent
    }

    private var fill: Color {
        switch role {
        case .primary, .destructive:
            return accent.opacity(isHovering ? 0.85 : 1).color
        case .secondary:
            return ui.palette.surface.opacity(isHovering ? 0.9 : 0.55).color
        }
    }

    private var foreground: Color {
        switch role {
        case .primary, .destructive: return ui.palette.accentForeground.color
        case .secondary: return ui.palette.foreground.color
        }
    }

    private var border: Color {
        role == .secondary ? ui.palette.border.color : .clear
    }

    @ViewBuilder private var focusRing: some View {
        if isFocused {
            RoundedRectangle(cornerRadius: ui.controlRadius + 2.5, style: .continuous)
                .strokeBorder(accent.opacity(0.65).color, lineWidth: 2.5)
                .padding(-3)
        }
    }
}

/// The footer strip: key hints and buttons.
///
/// Hints sit beside the buttons when they fit and drop to their own line when
/// they don't, rather than truncating — a hint you can't finish reading is
/// worse than no hint, and the loud themes make everything wider.
struct PromptFooter<Buttons: View>: View {
    @Environment(\.ui) private var ui
    let hints: [String]
    @ViewBuilder var buttons: Buttons

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                hintText
                Spacer(minLength: 16)
                buttons
            }
            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 10) { buttons }
                hintText.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 16)
    }

    private var hintText: some View {
        Text(hints.joined(separator: "   "))
            .font(ui.captionFont)
            .foregroundStyle(ui.palette.secondary.color)
            .lineLimit(1)
            .fixedSize()
    }
}

/// Diagonal caution-tape striping.
///
/// Drawn with Canvas rather than a repeating image so it scales with the panel
/// and picks up the theme's own two colours.
struct HazardStripes: View {
    let bright: Color
    let dark: Color

    /// Width of one stripe. 12pt reads as tape rather than as a texture at the
    /// 10pt band height the chrome uses.
    private let stripeWidth: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bright))
            // Each dark stripe is a parallelogram sheared by the band height,
            // giving the 45° lean. Start a full band-width to the left so the
            // leading edge is a partial stripe, not a clean seam.
            var leadingEdge = -size.height
            while leadingEdge < size.width + size.height {
                var stripe = Path()
                stripe.move(to: CGPoint(x: leadingEdge, y: size.height))
                stripe.addLine(to: CGPoint(x: leadingEdge + stripeWidth, y: size.height))
                stripe.addLine(to: CGPoint(x: leadingEdge + stripeWidth + size.height, y: 0))
                stripe.addLine(to: CGPoint(x: leadingEdge + size.height, y: 0))
                stripe.closeSubpath()
                context.fill(stripe, with: .color(dark))
                leadingEdge += stripeWidth * 2
            }
        }
        .accessibilityHidden(true)
    }
}
