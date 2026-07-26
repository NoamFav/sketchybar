#!/usr/bin/env bash
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

BREW_VERSION=$(brew --version 2>/dev/null | head -1 | awk '{print $2}')
JSON=$(brew outdated --json=v2 2>/dev/null)

echo "$JSON" | jq -r --arg ver "$BREW_VERSION" '
  (.formulae | length) as $fc |
  (.casks | length) as $cc |
  "SUMMARY|\($fc)|\($cc)|\($ver)",
  (.formulae[] | "formula|\(.name)|\(.installed_versions[0])|\(.current_version)"),
  (.casks[] | "cask|\(.name)|\(.installed_versions[0])|\(.current_version)")
'
