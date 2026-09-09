#!/usr/bin/env bash
# Regenerates Resources/AppIcon.icns from scripts/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
swift scripts/make-icon.swift
mkdir -p Resources
iconutil -c icns PrettyPrompt.iconset -o Resources/AppIcon.icns
rm -rf PrettyPrompt.iconset
echo "✓ Resources/AppIcon.icns"
