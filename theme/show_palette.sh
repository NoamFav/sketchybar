#!/usr/bin/env bash
# Print the current wallpaper-derived palette as terminal color swatches.
# Reads core/colors_generated.sh (the same contract shell rc/tmux consume),
# so it always reflects whatever `sb sync-theme` last generated.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../core/colors_generated.sh"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "No palette generated yet — run 'sb sync-theme' first." >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

names=(BLACK WHITE GREY RED GREEN BLUE YELLOW ORANGE MAGENTA BG1 BG2 ACCENT)

for name in "${names[@]}"; do
    var="SKETCHYBAR_COLOR_${name}"
    hex="${!var:-}"
    [[ -z "$hex" ]] && continue
    hex="${hex#\#}"
    r=$((16#${hex:0:2}))
    g=$((16#${hex:2:2}))
    b=$((16#${hex:4:2}))
    printf "%-9s #%-8s \033[38;2;%d;%d;%dm██████\033[0m\n" "${name,,}:" "$hex" "$r" "$g" "$b"
done

echo
for i in 1 2 3; do
    accent_var="SKETCHYBAR_COLOR_ACCENT_${i}"
    bg1_var="SKETCHYBAR_COLOR_BG1_${i}"
    bg2_var="SKETCHYBAR_COLOR_BG2_${i}"
    accent="${!accent_var:-}"
    [[ -z "$accent" ]] && continue
    bg1="${!bg1_var#\#}"; bg2="${!bg2_var#\#}"; acc="${accent#\#}"
    read -r ar ag ab <<< "$((16#${acc:0:2})) $((16#${acc:2:2})) $((16#${acc:4:2}))"
    read -r b1r b1g b1b <<< "$((16#${bg1:0:2})) $((16#${bg1:2:2})) $((16#${bg1:4:2}))"
    read -r b2r b2g b2b <<< "$((16#${bg2:0:2})) $((16#${bg2:2:2})) $((16#${bg2:4:2}))"
    printf "display %d:  accent #%-8s \033[38;2;%d;%d;%dm██████\033[0m  bg1 #%-8s \033[38;2;%d;%d;%dm██████\033[0m  bg2 #%-8s \033[38;2;%d;%d;%dm██████\033[0m\n" \
        "$i" "$acc" "$ar" "$ag" "$ab" "$bg1" "$b1r" "$b1g" "$b1b" "$bg2" "$b2r" "$b2g" "$b2b"
done
