#!/usr/bin/env bash
# Generate colors_generated.lua from the current wallpaper.
# Source priority per display:
#   1. Backdrop Library thumbnail (via com.cindori.Backdrop prefs UUID)
#   2. osascript (static image wallpapers)
#   3. screencapture (needs Screen Recording permission)
#   4. Backdrop/macOS aerial thumbnail cache
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
EXTRACT_PY="$SCRIPT_DIR/extract_colors.py"
GENERATE_PY="$SCRIPT_DIR/generate_lua.py"
OUTPUT="$CONFIG_DIR/colors_generated.lua"
CACHE_DIR="$SCRIPT_DIR/.cache"
PYTHON="${PYTHON:-python3}"

BACKDROP_THUMBS="$HOME/Library/Application Support/Backdrop/Library/Thumbnails"
AERIAL_THUMBS="$HOME/Library/Application Support/com.apple.wallpaper/aerials/thumbnails"

mkdir -p "$CACHE_DIR"

# ── Wallpaper source resolution ────────────────────────────────────────────────

get_backdrop_uuid() {
    defaults read com.cindori.Backdrop librarySelectedItemIdsBySection 2>/dev/null \
        | awk -F '"' '/All/{print $2}'
}

get_backdrop_thumbnail() {
    local uuid
    uuid=$(get_backdrop_uuid)
    [[ -z "$uuid" ]] && return

    local large="$BACKDROP_THUMBS/${uuid}-large.heic"
    local small="$BACKDROP_THUMBS/${uuid}.heic"

    if [[ -f "$large" ]]; then echo "$large"
    elif [[ -f "$small" ]]; then echo "$small"
    fi
}

get_wallpaper_osascript() {
    local path
    path=$(osascript -e "tell application \"System Events\" to get picture of desktop $1" 2>/dev/null || echo "")
    [[ "$path" == "missing value" || -z "$path" ]] && echo "" || echo "$path"
}

get_wallpaper_screencapture() {
    local out="$CACHE_DIR/screen_d${1}.png"
    screencapture -x -D "$1" "$out" 2>/dev/null && echo "$out" || echo ""
}

get_aerial_thumbnail() {
    [[ -d "$AERIAL_THUMBS" ]] || return
    find "$AERIAL_THUMBS" -name "*.png" -print0 2>/dev/null \
        | xargs -0 ls -t 2>/dev/null | head -1
}

get_wallpaper() {
    local display="$1"

    # 1. Backdrop (best source — high-quality HEIC thumbnail, always available)
    local path
    path=$(get_backdrop_thumbnail)
    [[ -n "$path" ]] && { echo "$path"; return; }

    # 2. osascript (static image wallpapers)
    path=$(get_wallpaper_osascript "$display")
    [[ -n "$path" && -f "$path" ]] && { echo "$path"; return; }

    # 3. screencapture (requires Screen Recording permission)
    path=$(get_wallpaper_screencapture "$display")
    [[ -n "$path" && -f "$path" ]] && { echo "$path"; return; }

    # 4. Aerial thumbnail fallback
    path=$(get_aerial_thumbnail)
    [[ -n "$path" && -f "$path" ]] && { echo "$path"; return; }

    echo ""
}

extract_with_cache() {
    local path="$1"
    if [[ -z "$path" || ! -f "$path" ]]; then
        echo "{}"
        return
    fi
    local hash
    hash=$(md5 -q "$path" 2>/dev/null || md5sum "$path" | awk '{print $1}')
    local cache="$CACHE_DIR/${hash}.json"
    if [[ ! -f "$cache" ]]; then
        if ! "$PYTHON" "$EXTRACT_PY" "$path" > "$cache" 2>/dev/null; then
            rm -f "$cache"
            echo "{}"
            return
        fi
    fi
    cat "$cache"
}

# ── Parse args ─────────────────────────────────────────────────────────────────

MANUAL_IMAGE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --image|-i) MANUAL_IMAGE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# ── Gather wallpaper sources ───────────────────────────────────────────────────

if [[ -n "$MANUAL_IMAGE" ]]; then
    WP1="$MANUAL_IMAGE"; WP2="$MANUAL_IMAGE"; WP3="$MANUAL_IMAGE"
    echo "Using manual image: $MANUAL_IMAGE" >&2
else
    WP1=$(get_wallpaper 1)
    WP2=$(get_wallpaper 2)
    WP3=$(get_wallpaper 3)

    [[ -n "$WP1" ]] && echo "Display 1: $(basename "$WP1")" >&2 || echo "Display 1: no source (using TN fallback)" >&2
    [[ -n "$WP2" ]] && echo "Display 2: $(basename "$WP2")" >&2 || echo "Display 2: no source (using TN fallback)" >&2
    [[ -n "$WP3" ]] && echo "Display 3: $(basename "$WP3")" >&2 || echo "Display 3: no source (using TN fallback)" >&2
fi

# ── Extract and generate ───────────────────────────────────────────────────────

extract_with_cache "$WP1" > "$CACHE_DIR/current_d1.json"
extract_with_cache "$WP2" > "$CACHE_DIR/current_d2.json"
extract_with_cache "$WP3" > "$CACHE_DIR/current_d3.json"

"$PYTHON" "$GENERATE_PY" \
    "$CACHE_DIR/current_d1.json" \
    "$CACHE_DIR/current_d2.json" \
    "$CACHE_DIR/current_d3.json" \
    "$OUTPUT"
