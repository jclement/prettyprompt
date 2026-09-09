// The themes that ship in the binary.
//
// These are the reference implementations of the Theme shape: anything a
// built-in can express, a user's JSON theme can too. Order matters — it is the
// order `prettyprompt themes` prints, so the sensible ones come first and the
// jokes come last.

import Foundation

enum BuiltInThemes {
    /// Used when neither the command line nor the config file names a theme.
    static let defaultName = "auto"

    static let all: [Theme] = [
        auto, dark, light, danger, doom, hotdog, matrix, synthwave, nord, paper, terminal,
    ]

    static func named(_ name: String) -> Theme? {
        all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    // ---- The native trio ----
    //
    // One palette pair, three themes: `auto` follows the system, `dark` and
    // `light` pin it. Sharing the palettes keeps them honestly identical.

    private static let nativeLight = Palette(
        background: ThemeColor("#FBFBFDF2"),
        surface: ThemeColor("#0000000D"),
        foreground: ThemeColor("#14141B"),
        secondary: ThemeColor("#5B5B6B"),
        accent: ThemeColor("#2F6FED"),
        accentForeground: ThemeColor("#FFFFFF"),
        border: ThemeColor("#00000024"),
        danger: ThemeColor("#D93636"))

    private static let nativeDark = Palette(
        background: ThemeColor("#1C1C22E6"),
        surface: ThemeColor("#FFFFFF14"),
        foreground: ThemeColor("#F2F2F7"),
        secondary: ThemeColor("#9A9AA8"),
        accent: ThemeColor("#5B8CFF"),
        accentForeground: ThemeColor("#0B1020"),
        border: ThemeColor("#FFFFFF24"),
        danger: ThemeColor("#FF5C5C"))

    static let auto = Theme(
        name: "auto",
        summary: "Follows the system appearance. The default.",
        appearance: .system,
        light: nativeLight,
        dark: nativeDark)

    static let dark = Theme(
        name: "dark",
        summary: "Native dark, whatever the system is doing.",
        appearance: .dark,
        light: nativeLight,
        dark: nativeDark)

    static let light = Theme(
        name: "light",
        summary: "Native light, whatever the system is doing.",
        appearance: .light,
        light: nativeLight,
        dark: nativeDark)

    // ---- The opinionated ones ----

    /// For the questions you do not want answered on autopilot: hazard yellow
    /// on black, caution tape top and bottom, everything in caps. Deliberately
    /// unlike every other prompt on the machine so it cannot be muscle-memoried
    /// through.
    static let danger = Theme.fixed(
        name: "danger",
        summary:
            "Caution tape. Hazard yellow on black, red accents. For questions that deserve a pause.",
        palette: Palette(
            background: ThemeColor("#0F0D08"),
            surface: ThemeColor("#241E0B"),
            foreground: ThemeColor("#FFD400"),
            secondary: ThemeColor("#C9AE45"),
            accent: ThemeColor("#D81E05"),
            accentForeground: ThemeColor("#FFFFFF"),
            border: ThemeColor("#FFD400"),
            danger: ThemeColor("#D81E05")),
        style: Style(
            cornerRadius: 2,
            borderWidth: 3,
            material: false,
            fontFamily: .system,
            titleSize: 21,
            titleWeight: .heavy,
            uppercaseTitle: true,
            hazardStripes: true,
            shadowRadius: 55,
            shadowOpacity: 0.75))

    static let doom = Theme.fixed(
        name: "doom",
        summary: "Rip and tear. Blood red on gunmetal, in caps.",
        palette: Palette(
            background: ThemeColor("#120505"),
            surface: ThemeColor("#2A0C0C"),
            foreground: ThemeColor("#E8D8B8"),
            secondary: ThemeColor("#A88C64"),
            accent: ThemeColor("#B31212"),
            accentForeground: ThemeColor("#FFE8D0"),
            border: ThemeColor("#5A1212"),
            danger: ThemeColor("#FF3B21")),
        style: Style(
            cornerRadius: 4,
            borderWidth: 2,
            material: false,
            fontFamily: .monospaced,
            titleSize: 20,
            titleWeight: .heavy,
            uppercaseTitle: true,
            shadowRadius: 50,
            shadowOpacity: 0.7))

    static let hotdog = Theme.fixed(
        name: "hotdog",
        summary: "Hot Dog Stand. Windows 3.1's greatest crime, faithfully.",
        palette: Palette(
            background: ThemeColor("#FFFF00"),
            surface: ThemeColor("#FF0000"),
            foreground: ThemeColor("#000000"),
            secondary: ThemeColor("#8B0000"),
            accent: ThemeColor("#FF0000"),
            accentForeground: ThemeColor("#FFFF00"),
            border: ThemeColor("#000000"),
            danger: ThemeColor("#000000")),
        style: Style(
            cornerRadius: 0,
            borderWidth: 3,
            material: false,
            fontFamily: .system,
            titleSize: 20,
            titleWeight: .heavy,
            uppercaseTitle: true,
            shadowRadius: 0,
            shadowOpacity: 0.5))

    static let matrix = Theme.fixed(
        name: "matrix",
        summary: "Phosphor green on black. Wake up, Neo.",
        palette: Palette(
            background: ThemeColor("#000000F5"),
            surface: ThemeColor("#00220E"),
            foreground: ThemeColor("#00FF41"),
            secondary: ThemeColor("#00A62B"),
            accent: ThemeColor("#00FF41"),
            accentForeground: ThemeColor("#001206"),
            border: ThemeColor("#00A62B"),
            danger: ThemeColor("#FF4136")),
        style: Style(
            cornerRadius: 2,
            borderWidth: 1,
            material: false,
            fontFamily: .monospaced,
            titleSize: 18,
            titleWeight: .bold,
            uppercaseTitle: false,
            shadowRadius: 40,
            shadowOpacity: 0.8))

    static let synthwave = Theme.fixed(
        name: "synthwave",
        summary: "Miami sunset. Hot pink on deep violet.",
        palette: Palette(
            background: ThemeColor("#1A0B2EF2"),
            surface: ThemeColor("#2D1B4E"),
            foreground: ThemeColor("#F5E9FF"),
            secondary: ThemeColor("#B39DDB"),
            accent: ThemeColor("#FF2E97"),
            accentForeground: ThemeColor("#14001F"),
            border: ThemeColor("#7B2CBF"),
            danger: ThemeColor("#FF6B6B")),
        style: Style(
            cornerRadius: 18,
            borderWidth: 1,
            material: true,
            fontFamily: .rounded,
            titleSize: 20,
            titleWeight: .bold,
            uppercaseTitle: false,
            shadowRadius: 55,
            shadowOpacity: 0.5))

    static let nord = Theme.fixed(
        name: "nord",
        summary: "Cold and calm. The Nord palette.",
        palette: Palette(
            background: ThemeColor("#2E3440F2"),
            surface: ThemeColor("#3B4252"),
            foreground: ThemeColor("#ECEFF4"),
            secondary: ThemeColor("#9AA7B8"),
            accent: ThemeColor("#88C0D0"),
            accentForeground: ThemeColor("#2E3440"),
            border: ThemeColor("#4C566A"),
            danger: ThemeColor("#BF616A")),
        style: Style(
            cornerRadius: 12,
            borderWidth: 1,
            material: true,
            fontFamily: .system,
            titleSize: 19,
            titleWeight: .semibold,
            uppercaseTitle: false,
            shadowRadius: 40,
            shadowOpacity: 0.4))

    static let paper = Theme.fixed(
        name: "paper",
        summary: "Warm stock, serif type. For prompts that want to be read.",
        palette: Palette(
            background: ThemeColor("#F6F1E7FA"),
            surface: ThemeColor("#0000000A"),
            foreground: ThemeColor("#2B2622"),
            secondary: ThemeColor("#6E6459"),
            accent: ThemeColor("#7A5C3E"),
            accentForeground: ThemeColor("#FDFAF3"),
            border: ThemeColor("#00000026"),
            danger: ThemeColor("#A33A2A")),
        style: Style(
            cornerRadius: 8,
            borderWidth: 1,
            material: true,
            fontFamily: .serif,
            titleSize: 21,
            titleWeight: .semibold,
            uppercaseTitle: false,
            shadowRadius: 35,
            shadowOpacity: 0.28))

    static let terminal = Theme.fixed(
        name: "terminal",
        summary: "Square corners, no blur, monospace. Looks like the shell that called it.",
        palette: Palette(
            background: ThemeColor("#000000"),
            surface: ThemeColor("#141414"),
            foreground: ThemeColor("#E6E6E6"),
            secondary: ThemeColor("#8A8A8A"),
            accent: ThemeColor("#FFFFFF"),
            accentForeground: ThemeColor("#000000"),
            border: ThemeColor("#3A3A3A"),
            danger: ThemeColor("#FF5F56")),
        style: Style(
            cornerRadius: 0,
            borderWidth: 1,
            material: false,
            fontFamily: .monospaced,
            titleSize: 18,
            titleWeight: .bold,
            uppercaseTitle: false,
            shadowRadius: 30,
            shadowOpacity: 0.6))
}
