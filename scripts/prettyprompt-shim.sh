#!/bin/bash
# Installed as `prettyprompt` in Homebrew's bin.
#
# Runs the executable inside the bundle rather than a copy of it, so Bundle.main
# resolves to PrettyPrompt.app and the process gets an Info.plist and an
# activation policy. exec keeps the exit code, stdin, stdout and stderr exactly
# as the caller left them — the entire shell contract depends on that.
exec "@BUNDLE@/Contents/MacOS/prettyprompt" "$@"
