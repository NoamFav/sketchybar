#!/usr/bin/env bash
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
# Hardware::CPU.cores crashes when brew is spawned from sketchybar's exec
# (subprocess exit-status doesn't propagate in that context). Short-circuit it.
export HOMEBREW_DOWNLOAD_CONCURRENCY=16

BREW_VERSION=$(brew --version 2>/dev/null | head -1 | awk '{print $2}')

# Formula and cask outdated checks are split so a cask-side crash
# (auto_updates_bundle_outdated? also hits the exit-status bug above)
# can't take down formula data with it.
FORMULA_JSON=$(brew outdated --formula --json=v2 2>/dev/null)
CASK_JSON=$(brew outdated --cask --json=v2 2>/dev/null)

FC=$(echo "$FORMULA_JSON" | jq -r '.formulae | length' 2>/dev/null)
CC=$(echo "$CASK_JSON" | jq -r '.casks | length' 2>/dev/null)
[[ "$FC" =~ ^[0-9]+$ ]] || FC=0
[[ "$CC" =~ ^[0-9]+$ ]] || CC=0

FI=$(brew list --formula -1 2>/dev/null | wc -l | tr -d ' ')
CI=$(brew list --cask -1 2>/dev/null | wc -l | tr -d ' ')
[[ "$FI" =~ ^[0-9]+$ ]] || FI=0
[[ "$CI" =~ ^[0-9]+$ ]] || CI=0

echo "SUMMARY|$FC|$CC|$BREW_VERSION|$FI|$CI"
echo "$FORMULA_JSON" | jq -r '.formulae[]? | "formula|\(.name)|\(.installed_versions[0])|\(.current_version)"' 2>/dev/null
echo "$CASK_JSON" | jq -r '.casks[]? | "cask|\(.name)|\(.installed_versions[0])|\(.current_version)"' 2>/dev/null
