// Rendering prompts to PNG without opening a window.
//
// Development tool, never shipped in the bundle. It exists for two reasons: a
// theme change can be reviewed by looking at it rather than by launching eleven
// prompts, and the README's screenshots are generated rather than hand-taken,
// so they cannot drift from what the code actually draws.
//
// NSViewRepresentable content (the vibrancy blur, the key monitor) renders as
// nothing under ImageRenderer, so translucent themes appear over the mock
// desktop gradient below instead of a real one. Close enough to judge a palette.

import AppKit
import SwiftUI

public enum Gallery {
    /// One sample prompt per theme, plus the four prompt kinds in the default
    /// theme, written as PNGs into `directory`.
    @MainActor
    public static func render(into directory: URL, scale: CGFloat = 2) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Both focus states of the theme that made the problem visible.
        for (suffix, yes) in [("focus-action", true), ("focus-cancel", false)] {
            var spec = confirmSample(theme: BuiltInThemes.danger)
            spec.kind = .confirm(
                ConfirmSpec(
                    affirmative: "Deploy", negative: "Not now",
                    defaultsToYes: yes, destructive: true))
            try write(
                spec: spec,
                to: directory.appendingPathComponent("danger-\(suffix).png"), scale: scale)
        }

        for theme in BuiltInThemes.all {
            try write(
                spec: confirmSample(theme: theme),
                to: directory.appendingPathComponent("theme-\(theme.name).png"),
                scale: scale)
        }

        let showcase = BuiltInThemes.auto
        for (name, spec) in kindSamples(theme: showcase) {
            try write(
                spec: spec,
                to: directory.appendingPathComponent("prompt-\(name).png"),
                scale: scale)
        }
    }

    // ---- Samples ----

    private static func confirmSample(theme: Theme) -> PromptSpec {
        PromptSpec(
            title: "Deploy to production?",
            message: """
                This restarts **3 services** and runs `db:migrate:prod`.

                - api-gateway
                - worker-pool
                - scheduler
                """,
            icon: "exclamationmark.triangle.fill",
            kind: .confirm(
                ConfirmSpec(
                    affirmative: "Deploy", negative: "Not now",
                    defaultsToYes: true, destructive: true)),
            theme: theme,
            width: 460)
    }

    private static func kindSamples(theme: Theme) -> [(String, PromptSpec)] {
        [
            (
                "choose",
                PromptSpec(
                    title: "Which branch?",
                    message: "Checked out in the current worktree.",
                    icon: "arrow.triangle.branch",
                    kind: .choose(
                        ChooseSpec(options: [
                            ChoiceOption(rawValue: "develop\tThe default branch"),
                            ChoiceOption(rawValue: "feature/prompt-themes\tAhead by 3 commits"),
                            ChoiceOption(rawValue: "expr/vibrancy\tStale, 2 weeks old"),
                        ])),
                    theme: theme, width: 460)
            ),

            (
                "multi",
                PromptSpec(
                    title: "What should the release include?",
                    icon: "shippingbox.fill",
                    kind: .choose(
                        ChooseSpec(
                            options: [
                                ChoiceOption(rawValue: "Formula update"),
                                ChoiceOption(rawValue: "Release notes"),
                                ChoiceOption(rawValue: "Docker image"),
                                ChoiceOption(rawValue: "Announcement"),
                            ], allowsMultiple: true, preselected: [0, 1])),
                    theme: theme, width: 460)
            ),

            // A real caller's prompt (an SSH agent asking for approval), kept as
            // a sample because its option labels are long enough to have
            // exposed the row-truncation bug.
            (
                "long-labels",
                PromptSpec(
                    title: "devtun — ssh agent",
                    message: """
                        `bedev` is asking for:

                        ssh-rsa SHA256:01tagjHSHRivNwXVT1m8YdyAFc8c8fkFDvvG+usELs4 → git.onewheelgeek.net
                        """,
                    icon: "🔒",
                    kind: .choose(
                        ChooseSpec(
                            options: [
                                ChoiceOption(rawValue: "Yes, once"),
                                ChoiceOption(
                                    rawValue: "Yes, this key for git.onewheelgeek.net — 5m0s"),
                                ChoiceOption(
                                    rawValue:
                                        "Yes, this key for git.onewheelgeek.net — this session"),
                                ChoiceOption(
                                    rawValue: "Yes, this key for git.onewheelgeek.net — always"),
                                ChoiceOption(rawValue: "Yes to anything from bedev — 5m0s"),
                                ChoiceOption(rawValue: "Yes to anything from bedev — this session"),
                                ChoiceOption(rawValue: "No, and stop asking this session"),
                                ChoiceOption(
                                    rawValue:
                                        "Never, this key for git.onewheelgeek.net (write to config)"
                                ),
                            ], preselected: [2])),
                    theme: BuiltInThemes.danger, width: 460)
            ),

            (
                "input",
                PromptSpec(
                    title: "Name the branch",
                    message: "Prefixed with `feature/` automatically.",
                    icon: "pencil.line",
                    kind: .input(InputSpec(placeholder: "prompt-themes", initialValue: "")),
                    theme: theme, width: 460)
            ),

            (
                "alert",
                PromptSpec(
                    title: "Build failed",
                    message: "`swift build` exited 1 after 42s. The log is in *.build/last.log*.",
                    icon: "xmark.octagon.fill",
                    kind: .alert(buttonLabel: "Show log"),
                    theme: theme, width: 460)
            ),
        ]
    }

    // ---- Rendering ----

    @MainActor
    private static func write(spec: PromptSpec, to url: URL, scale: CGFloat) throws {
        let coordinator = PromptCoordinator(spec: spec)
        let renderer = ImageRenderer(
            content: MockDesktop {
                PromptRootView(coordinator: coordinator)
                    .environment(\.offscreenRendering, true)
            })
        renderer.scale = scale

        guard let image = renderer.nsImage,
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw GalleryError.renderFailed(url.lastPathComponent)
        }
        try png.write(to: url)
    }

    enum GalleryError: Error, CustomStringConvertible {
        case renderFailed(String)

        var description: String {
            switch self {
            case let .renderFailed(name): return "could not render \(name)"
            }
        }
    }
}

/// Something for translucent themes to be translucent against.
private struct MockDesktop<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.24, blue: 0.34),
                    Color(red: 0.36, green: 0.28, blue: 0.42),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            content
        }
        .fixedSize()
    }
}
