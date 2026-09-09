// The visual vocabulary every prompt renders through.
//
// A Theme is pure data: two palettes (light and dark) plus a Style describing
// shape, typography and material. Nothing here knows what a prompt looks like —
// the views ask the theme for colours and metrics and draw themselves. That
// split is what lets a user drop a JSON file in ~/.config/prettyprompt/themes/
// and get a first-class theme without touching Swift.

import SwiftUI

// ---- Colour ----

/// A colour parsed from a `#RRGGBB` or `#RRGGBBAA` hex string.
///
/// Stored as components rather than a `Color` so themes stay `Codable` and can
/// be compared in tests without touching SwiftUI's rendering machinery.
struct ThemeColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    /// Parses `#RGB`, `#RRGGBB` or `#RRGGBBAA`, with or without the leading `#`.
    /// Returns nil for anything else so a malformed theme file fails loudly
    /// rather than silently rendering black-on-black.
    init?(hex rawValue: String) {
        var digits = rawValue.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }

        // Expand shorthand (#f0a → #ff00aa) before parsing.
        if digits.count == 3 {
            digits = digits.map { "\($0)\($0)" }.joined()
        }
        guard digits.count == 6 || digits.count == 8,
            digits.allSatisfy({ $0.isHexDigit }),
            let packed = UInt64(digits, radix: 16)
        else { return nil }

        let hasAlpha = digits.count == 8
        let shift = hasAlpha ? 24 : 16
        red = Double((packed >> UInt64(shift)) & 0xFF) / 255
        green = Double((packed >> UInt64(shift - 8)) & 0xFF) / 255
        blue = Double((packed >> UInt64(shift - 16)) & 0xFF) / 255
        alpha = hasAlpha ? Double(packed & 0xFF) / 255 : 1
    }

    init(_ hex: String) {
        // Built-in themes are compiled in and their literals are checked by the
        // theme tests, so an unparseable one is a programmer error, not input.
        guard let parsed = ThemeColor(hex: hex) else {
            preconditionFailure("built-in theme contains invalid hex colour: \(hex)")
        }
        self = parsed
    }

    /// Decodes from a bare JSON string ("#1e1e2e") rather than an object, so
    /// hand-written theme files read like CSS.
    init(from decoder: Decoder) throws {
        let hex = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = ThemeColor(hex: hex) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "\"\(hex)\" is not a hex colour like #1e1e2e or #1e1e2ecc"))
        }
        self = parsed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }

    var hexString: String {
        let channels = [red, green, blue].map { Int(($0 * 255).rounded()) }
        let base = String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
        guard alpha < 1 else { return base }
        return base + String(format: "%02X", Int((alpha * 255).rounded()))
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    /// The same colour, scaled toward transparent — used for hover fills and
    /// dividers so a theme only has to name each colour once.
    ///
    /// Scales rather than replaces: palette entries like `surface` are already
    /// near-transparent overlays in light themes, and overwriting their alpha
    /// would turn a 5%-black wash into a 55%-black slab.
    func opacity(_ value: Double) -> ThemeColor {
        ThemeColor(red: red, green: green, blue: blue, alpha: alpha * value)
    }

    private init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

// ---- Palette ----

/// Every colour a prompt can draw with, in one appearance.
struct Palette: Codable, Equatable {
    /// The panel itself. When `Style.material` is set this tints the blur, so
    /// it usually wants an alpha below 1.
    let background: ThemeColor
    /// Fill behind text fields, list rows and unselected buttons.
    let surface: ThemeColor
    /// Primary text.
    let foreground: ThemeColor
    /// Supporting text: the message line, option subtitles, key hints.
    let secondary: ThemeColor
    /// Selection, focus rings, the default button.
    let accent: ThemeColor
    /// Text drawn on top of `accent`.
    let accentForeground: ThemeColor
    /// The panel's outer hairline and field borders.
    let border: ThemeColor
    /// Destructive confirmations and the timeout bar as it runs out.
    let danger: ThemeColor

    /// Whether the panel reads as dark, by perceived luminance.
    ///
    /// Used to pick the window's appearance so a light theme never gets a dark
    /// frosted backdrop behind it. The weights are the standard sRGB luma
    /// coefficients; 0.5 is the usual cut for "should text on this be white?".
    var isDarkBackground: Bool {
        let luma = 0.2126 * background.red + 0.7152 * background.green + 0.0722 * background.blue
        return luma < 0.5
    }
}

// ---- Style ----

/// Shape, typography and material — the non-colour half of a theme's identity.
/// This is what makes `hotdog` feel like Windows 3.1 and `dark` feel like Raycast
/// even though both draw the same views.
struct Style: Codable, Equatable {
    enum FontFamily: String, Codable {
        case system, monospaced, rounded, serif

        var design: Font.Design {
            switch self {
            case .system: return .default
            case .monospaced: return .monospaced
            case .rounded: return .rounded
            case .serif: return .serif
            }
        }
    }

    /// Corner radius of the panel; controls and rows derive from it.
    var cornerRadius: CGFloat = 16
    /// Panel hairline width. 0 draws no border.
    var borderWidth: CGFloat = 1
    /// When true the panel sits on a translucent blur that samples the desktop
    /// behind it. Opaque themes (hotdog, terminal) turn this off.
    var material: Bool = true
    var fontFamily: FontFamily = .system
    /// Title size in points. Everything else scales from the system defaults.
    var titleSize: CGFloat = 19
    var titleWeight: FontWeightName = .semibold
    /// Draws titles in caps with widened tracking — loud themes want this.
    var uppercaseTitle: Bool = false
    /// Bands of diagonal caution-tape striping across the top and bottom of the
    /// panel. Reserved for themes that exist to say "read this properly".
    var hazardStripes: Bool = false
    var shadowRadius: CGFloat = 40
    var shadowOpacity: Double = 0.34
    /// The system sound this theme plays when a prompt asks for one. A theme's
    /// voice is part of its character: danger thuds, hotdog honks. nil falls
    /// back to a neutral chime.
    var sound: String?

    enum FontWeightName: String, Codable {
        case regular, medium, semibold, bold, heavy

        var weight: Font.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            case .heavy: return .heavy
            }
        }
    }
}

// ---- Theme ----

/// A named look. `light` and `dark` are both always present; `appearance`
/// decides which one a given run actually uses.
struct Theme: Codable, Equatable {
    /// How a theme picks between its two palettes.
    enum Appearance: String, Codable {
        /// Follow the system setting — the only value that can change mid-run.
        case system
        case light
        case dark
    }

    var name: String
    /// One line shown by `prettyprompt themes`.
    var summary: String
    var appearance: Appearance = .system
    var light: Palette
    var dark: Palette
    var style: Style = Style()

    /// The palette to draw with, given what the system is currently doing.
    /// `systemIsDark` is ignored unless the theme follows the system.
    func palette(systemIsDark: Bool) -> Palette {
        switch appearance {
        case .system: return systemIsDark ? dark : light
        case .light: return light
        case .dark: return dark
        }
    }

    /// A theme with one fixed look — `light` and `dark` are the same palette.
    static func fixed(name: String, summary: String, palette: Palette, style: Style) -> Theme {
        Theme(
            name: name, summary: summary, appearance: .dark,
            light: palette, dark: palette, style: style)
    }
}
