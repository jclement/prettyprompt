#!/usr/bin/env bash
# Assembles PrettyPrompt.app around the compiled binary.
#
# The bundle is not decoration. A bare Mach-O executable launched from a shell
# cannot reliably take keyboard focus or register an activation policy, so the
# CLI you install is a two-line shim that execs the binary *inside* this bundle
# — which gives it an Info.plist, an activation policy and a working
# NSApplication, while stdout stays wired to the terminal that called it.
#
#   ./build-app.sh              release build for this machine
#   ./build-app.sh --debug      fast build, for iterating
#   ./build-app.sh --universal  arm64 + x86_64, what CI ships
set -euo pipefail
cd "$(dirname "$0")"

APP="PrettyPrompt.app"
BUNDLE_ID="com.jsc.prettyprompt"
CONFIGURATION="release"
# Kept as a string: bash 3.2 (what macOS ships) cannot expand an empty array
# under `set -u`, and this script has to run on a stock machine.
ARCH_FLAGS=""

for argument in "$@"; do
  case "$argument" in
    --debug)     CONFIGURATION="debug" ;;
    --universal) ARCH_FLAGS="--arch arm64 --arch x86_64" ;;
    *) echo "unknown option: $argument" >&2; exit 2 ;;
  esac
done

# VERSION is set by CI from the tag. A local build reports the last tag, or
# 0.0.0 — which Version.swift reads back as "dev".
VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo 0.0.0)}"
COMMIT="${COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "→ building prettyprompt $VERSION ($CONFIGURATION)"
swift build -c "$CONFIGURATION" $ARCH_FLAGS
BINARY="$(swift build -c "$CONFIGURATION" $ARCH_FLAGS --show-bin-path)/prettyprompt"

echo "→ assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/prettyprompt"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>PrettyPrompt</string>
    <key>CFBundleDisplayName</key><string>PrettyPrompt</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>prettyprompt</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
    <!-- No Dock icon and no ⌘-Tab entry: a prompt is not an app you switch to. -->
    <key>LSUIElement</key><true/>
    <!-- Read back by Version.swift; Swift has no ldflags to stamp them in. -->
    <key>PPGitCommit</key><string>${COMMIT}</string>
    <key>PPBuildDate</key><string>${BUILD_DATE}</string>
</dict>
</plist>
PLIST

echo "APPL????" > "$APP/Contents/PkgInfo"

# Ad-hoc signature. Homebrew downloads are not quarantined, so this is enough
# for `brew install` to produce a runnable binary on Apple Silicon; a Developer
# ID signature would only matter if the bundle were distributed by download.
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 \
  || echo "  (codesign unavailable — the bundle will still run locally)"

echo "✓ $APP  ($VERSION, $COMMIT)"
