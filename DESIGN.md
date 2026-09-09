# prettyprompt — design

For someone changing this. [README.md](README.md) is for someone using it.

## What it is

A macOS CLI that opens one window, asks one question, prints the answer to stdout and
exits with a code that says what happened. Everything else — themes, markdown, timeouts
— serves that one sentence.

## Shape

```
Sources/
  prettyprompt/main.swift        Entry point. Parse → run → exit. Nothing else.
  PrettyPromptKit/
    CLI/
      RootCommand.swift          The command tree: choose, input, confirm, alert.
      ThemesCommand.swift        `themes` — list, preview, export.
      SharedOptions.swift        Flags every prompt understands + config merging.
      PromptSpec.swift           The contract between the CLI and the window.
      PromptOutcome.swift        What came back, and how it reaches stdout.
      PromptExit.swift           Exit codes and user-facing errors.
    Theme/
      Theme.swift                Colour, Palette, Style, Theme. Pure data, Codable.
      BuiltInThemes.swift        The eleven that ship.
      ThemeLoader.swift          Name → Theme, including ~/.config themes.
    UI/
      PromptPresenter.swift      The only event loop. present(spec) → outcome.
      PromptPanel.swift          The NSPanel, and which display it opens on.
      PromptChrome.swift         The shell every prompt draws inside + controls.
      ChooseView.swift           …
      InputView.swift            … the four prompt bodies.
      ConfirmView.swift          …
      AlertView.swift            …
      RichText.swift             Markdown blocks for --message.
      KeyMonitor.swift           Local NSEvent monitor + named key codes.
      VisualEffectBackground.swift  The masked blur.
      Gallery.swift              Offscreen PNG rendering. Development only.
    Support/
      Config.swift               ~/.config/prettyprompt/config.json
      Paths.swift                XDG paths, honouring XDG_CONFIG_HOME.
      Version.swift              Version read back out of the bundle's Info.plist.
      StandardInput.swift        Reading choose options from a pipe.
  gallery/main.swift             Three lines around Gallery.render.
```

The flow is always the same: a subcommand builds a `PromptSpec`, hands it to
`PromptPresenter.present`, gets a `PromptOutcome`, and `emit` turns that into stdout text
and an exit code. **Nothing in `UI/` decides anything about the shell**, and nothing in
`CLI/` draws.

## Key decisions

### 1. Swift and AppKit, not a terminal UI

The request was for a prompt that appears in front of you wherever you are, not in the
terminal that happens to be running the script. That rules out every TUI toolkit. AppKit
via SwiftUI gets the window, the blur, the focus behaviour and the type rendering for
free.

### 2. It ships as a `.app` bundle with a shim, not a bare binary

This is the load-bearing decision. A bare Mach-O executable launched from a shell has no
`Info.plist`, so it cannot reliably set an activation policy, take keyboard focus, or be
treated as an app by the window server. So `build-app.sh` assembles `PrettyPrompt.app`
(with `LSUIElement`, no Dock icon, no ⌘-Tab entry) and Homebrew installs a two-line shim
in `bin` that `exec`s the executable *inside* the bundle.

`exec` matters as much as the bundle: it keeps stdin, stdout, stderr and the exit code
exactly as the caller left them, so `$(prettyprompt input …)` behaves like any other
command.

### 3. Exit code 1 is reserved for "the user said no"

`if prettyprompt confirm …; then` has to read correctly, which means `confirm` needs 0
and 1 for its two answers. Runtime failures therefore use 70 (`EX_SOFTWARE`), usage
errors 2, timeout 124 (matching `timeout(1)`) and cancellation 130 (matching a SIGINT
exit). A cancelled prompt prints nothing at all, so a bare `$(...)` capture is never a
half-answer.

### 4. Themes are data, not code

A `Theme` is `Codable` and contains no view logic: two `Palette`s and a `Style`. The
views ask for colours and metrics. That is what lets a user drop JSON into
`~/.config/prettyprompt/themes/` and get a first-class theme, and what makes
`themes --export` a real starting point rather than a curiosity. Built-in names win over
files, so `--theme dark` means the same thing on every machine.

`Style.hazardStripes` is the one piece of theme-driven *decoration* rather than styling.
It exists because the `danger` theme's job is to be unmistakable from the corner of your
eye, and colour alone was not doing it.

### 5. Keyboard handling goes through a local NSEvent monitor

SwiftUI's `.onExitCommand` and focus-scoped key handling are not dependable enough for a
window whose entire purpose is keyboard-driven. `onKeyDown` installs an
`NSEvent.addLocalMonitorForEvents` monitor, so `⌘↩`, `⌘1`…`⌘9` and Esc fire regardless of
which control holds focus. Each view checks `Key.isCancel` first, which gives `--insist`
exactly one place to be honoured.

### 6. The blur masks itself, and AppKit's window shadow is off

`NSVisualEffectView` is an AppKit view inside SwiftUI. SwiftUI's `.clipShape` masks the
*SwiftUI* layer, not the AppKit view, so the effect view filled the whole window — and
because AppKit derives a window's drop shadow from the opacity of its content, the result
was a hard grey rectangle with jagged edges behind the rounded panel. The fix is
`maskImage` (a nine-part rounded rectangle) on the effect view, plus `hasShadow = false`
so the theme's own SwiftUI shadow is the only one.

### 7. The panel opens on the mouse's display

"The screen you're looking at" has no API. The pointer is the best proxy: better than the
focused window, which on a multi-display desk is often the one you walked away from.
`--screen focused` and `--screen <index>` exist for scripts that know better.

### 8. Short lists are not scroll views

A `ScrollViewReader` proposes the full available height to its content, which left a gap
under any list shorter than the screen. Lists of eight rows or fewer render as a plain
`VStack`; longer ones get the scroll view and the filter field. Fewer rows also means no
bounce and no scroll indicator for a three-item menu.

### 9. Version comes from `Info.plist`

Swift has no `-ldflags`. `build-app.sh` writes `CFBundleShortVersionString`, `PPGitCommit`
and `PPBuildDate` into the plist and `Version.swift` reads them back. A checkout build has
no tag and reports `dev`, which is also the signal that it is not a release.

### 10. The gallery renders offscreen

`mise run gallery` draws every theme to PNG with `ImageRenderer`, which is how the README
screenshots are produced and how a theme change gets reviewed without launching eleven
windows. AppKit-backed views (the blur, text fields) draw as a "not supported" glyph
there, so the views check `\.offscreenRendering` and substitute a flat tint and static
text. That is the one place production views know about the gallery, and it is the price
of documentation that cannot drift from the code.

## Data model

```
PromptSpec          title, message, icon, kind, theme, width, timeout,
                    timeoutBehaviour, insist, sound, screen
  └── PromptKind    .choose(ChooseSpec) | .input(InputSpec)
                    | .confirm(ConfirmSpec) | .alert(buttonLabel:)

PromptOutcome       .text | .chosen(values:indexes:) | .confirmed(Bool)
                    | .acknowledged | .cancelled | .timedOut
                      → exitCode, and OutcomeWriter → stdout

Theme               name, summary, appearance, light: Palette, dark: Palette, style
  ├── Palette       background, surface, foreground, secondary,
  │                 accent, accentForeground, border, danger
  └── Style         cornerRadius, borderWidth, material, fontFamily,
                    titleSize, titleWeight, uppercaseTitle, hazardStripes,
                    shadowRadius, shadowOpacity
```

Option strings split on the first tab: `value\tdescription`. Chosen because it survives
shell quoting and is what `cut` and `awk` already emit.

## Known limitations

- **No window server, no prompt.** Over SSH or from a root launchd daemon there is no
  session to draw into. There is an error for it, but the failure is real.
- **Only ad-hoc signed.** Fine for Homebrew, which does not quarantine its downloads.
  Distributing the bundle by download would need a Developer ID signature and
  notarisation.
- **`--insist` is honest but not a cage.** It removes Esc, the close path and the cancel
  button. It does not stop `kill`, and it should not.
- **One prompt per process.** There is no "form" with several fields. Chain two calls, or
  use `--multiline`.
- **The gallery cannot render text fields or the blur.** See decision 10. Real
  screenshots need a real screen.
- **No self-update.** Distributed tools here usually check GitHub for a newer release and
  can replace themselves. prettyprompt does not: `brew upgrade` is the only install path,
  and a prompt that occasionally pauses to talk to the network is a worse prompt.
