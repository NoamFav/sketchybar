#!/usr/bin/env bash

sb() {
    local BIN="${SB_BIN:-/opt/homebrew/bin/sketchybar}"
    local CFG="${SB_CONFIG:-$HOME/.config/sketchybar/sketchybarrc}"
    local MODE="${SB_MODE:-auto}"
    _exists() {
        command -v "$1" >/dev/null 2>&1
    }
    _running() {
        pgrep -x sketchybar >/dev/null 2>&1
    }
    _using_brew() {
        [[ "$MODE" == "brew" ]] && return 0
        [[ "$MODE" == "manual" ]] && return 1
        _exists brew || return 1
        brew services list 2>/dev/null | awk 'NR>1 && $1=="sketchybar" {print $2,$3}' | grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox,.venv,venv} -q . || return 1
        return 0
    }
    _start_manual() {
        if ! _exists "$BIN"; then
            echo "sb: sketchybar not found at $BIN"
            return 1
        fi
        nohup "$BIN" --config "$CFG" >/dev/null 2>&1 &
        disown
    }
    _stop_manual() {
        pkill -x sketchybar 2>/dev/null
    }
    _restart_manual() {
        _stop_manual
        sleep 0.2
        _start_manual
    }
    _reload_soft() {
        "$BIN" --reload >/dev/null 2>&1 || return 1
    }
    local cmd="${1:-toggle}"
    case "$cmd" in
    toggle) if _running; then
        if _using_brew; then
            brew services stop sketchybar >/dev/null 2>&1 || true
        else
            _stop_manual
        fi
        echo "sb: stopped"
    else
        if _using_brew; then
            brew services start sketchybar >/dev/null 2>&1 || true
        else
            _start_manual
        fi
        echo "sb: started"
    fi ;;
    start)
        if _running; then
            echo "sb: already running"
            return 0
        fi
        if _using_brew; then
            brew services start sketchybar
        else
            _start_manual
        fi
        ;;
    stop)
        if ! _running; then
            echo "sb: not running"
            return 0
        fi
        if _using_brew; then
            brew services stop sketchybar
        else
            _stop_manual
        fi
        ;;
    restart) if _using_brew; then
        brew services restart sketchybar
    else
        _restart_manual
    fi ;;
    reload)
        if ! _running; then
            echo "sb: not running"
            return 1
        fi
        _reload_soft && echo "sb: reloaded" || {
            echo "sb: soft reload failed; doing restart"
            sb restart
        }
        ;;
    status) if _running; then
        if _using_brew; then
            local st
            st="$(brew services list 2>/dev/null | awk 'NR>1 && $1=="sketchybar"{print $2,$3}')"
            echo "sb: running (brew ${st:-unknown})"
        else
            echo "sb: running (manual)"
        fi
    else
        echo "sb: stopped"
    fi ;;
    *)
        echo "sb: usage: sb [toggle|start|stop|restart|reload|status]"
        return 1
        ;;
    esac
}

sb "$@"
