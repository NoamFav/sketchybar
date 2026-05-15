#!/usr/bin/env bash
# Watch Backdrop's preferences for wallpaper changes and auto-regenerate the theme.
# Uses fswatch for near-instant response instead of polling.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE="$SCRIPT_DIR/generate.sh"
SKETCHYBAR="${SB_BIN:-/opt/homebrew/bin/sketchybar}"
PID_FILE="$SCRIPT_DIR/.watch.pid"
LOG_FILE="$SCRIPT_DIR/.watch.log"

# macOS writes this on every wallpaper switch (Backdrop plist flushes lazily)
WALLPAPER_INDEX="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
FSWATCH="${FSWATCH:-/opt/homebrew/bin/fswatch}"

_on_change() {
    sleep 1  # let Backdrop flush its prefs before we read the UUID
    echo "$(date '+%Y-%m-%d %H:%M:%S') wallpaper changed — regenerating theme" >> "$LOG_FILE"
    if bash "$GENERATE" >> "$LOG_FILE" 2>&1; then
        "$SKETCHYBAR" --reload >> "$LOG_FILE" 2>&1 || true
        echo "$(date '+%Y-%m-%d %H:%M:%S') theme applied" >> "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') generate.sh failed" >> "$LOG_FILE"
    fi
}

_watch_loop() {
    # fswatch fires on any write to the Backdrop plist (happens when wallpaper changes)
    # -o collapses rapid successive events into one; -1 exits after first event (loop handles restart)
    while true; do
        "$FSWATCH" -o --event Updated --event Created "$WALLPAPER_INDEX" 2>/dev/null | while read -r _; do
            _on_change
        done
        sleep 1  # brief pause before re-watching in case fswatch exits unexpectedly
    done
}

case "${1:-}" in
start)
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "theme-watch: already running (pid $(cat "$PID_FILE"))"
        exit 0
    fi
    if [[ ! -x "$FSWATCH" ]]; then
        echo "theme-watch: fswatch not found at $FSWATCH — install with: brew install fswatch"
        exit 1
    fi
    if [[ ! -f "$WALLPAPER_INDEX" ]]; then
        echo "theme-watch: wallpaper index not found ($WALLPAPER_INDEX missing)"
        exit 1
    fi
    _watch_loop &
    BGPID=$!
    echo "$BGPID" > "$PID_FILE"
    disown "$BGPID"
    echo "theme-watch: started (pid $BGPID, watching wallpaper index)"
    ;;

stop)
    if [[ -f "$PID_FILE" ]]; then
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            # Kill the loop and any fswatch children
            pkill -P "$pid" 2>/dev/null || true
            kill "$pid" 2>/dev/null || true
            rm -f "$PID_FILE"
            echo "theme-watch: stopped"
        else
            rm -f "$PID_FILE"
            echo "theme-watch: was not running"
        fi
    else
        echo "theme-watch: not running"
    fi
    ;;

status)
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "theme-watch: running (pid $(cat "$PID_FILE"), watching wallpaper index)"
    else
        echo "theme-watch: stopped"
    fi
    ;;

*)
    echo "Usage: watch.sh [start|stop|status]"
    exit 1
    ;;
esac
