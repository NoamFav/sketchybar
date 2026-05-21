#!/usr/bin/env python3
"""Generate an iTerm2 Dynamic Profile from a wallpaper palette JSON.

The profile inherits all non-color settings (font, keybindings, etc.) from
the parent profile named by PARENT_PROFILE, and overrides only colors.
iTerm2 reloads DynamicProfiles automatically — no restart needed.
"""

import json
import os
import sys

PROFILE_GUID   = "SKETCHYBAR-WALLPAPER-THEME-0001"
PROFILE_NAME   = "Wallpaper (Auto)"
PARENT_PROFILE = "Default"

DYNAMIC_PROFILES_DIR = os.path.expanduser(
    "~/Library/Application Support/iTerm2/DynamicProfiles"
)

# Tokyo Night fallback (matches colors.lua)
TN = {
    "black":   0xFF1A1B26,
    "white":   0xFFC0CAF5,
    "red":     0xFFF7768E,
    "green":   0xFF9ECE6A,
    "blue":    0xFF7AA2F7,
    "yellow":  0xFFE0AF68,
    "orange":  0xFFFF9E64,
    "magenta": 0xFFBB9AF7,
    "grey":    0xFF565F89,
    "bg1":     0xFF1F2335,
    "bg2":     0xFF24283B,
    "accent":  0xFF7AA2F7,
}


def _tn_hex(key):
    v = TN[key]
    return f"0x{v:08x}"


def _parse(hex_str):
    """0xAARRGGBB → (r, g, b, a) as floats 0..1"""
    v = int(hex_str, 16)
    a = ((v >> 24) & 0xFF) / 255.0
    r = ((v >> 16) & 0xFF) / 255.0
    g = ((v >>  8) & 0xFF) / 255.0
    b = (v         & 0xFF) / 255.0
    return r, g, b, a


def _col(hex_str, alpha=1.0):
    r, g, b, _ = _parse(hex_str)
    return {
        "Red Component":   r,
        "Green Component": g,
        "Blue Component":  b,
        "Alpha Component": alpha,
        "Color Space":     "sRGB",
    }


def build_profile(palette: dict) -> dict:
    def c(key, alpha=1.0):
        return _col(palette.get(key) or _tn_hex(key), alpha)

    # Map wallpaper palette onto iTerm2 color slots
    colors = {
        "Background Color":    c("black"),
        "Foreground Color":    c("white"),
        "Bold Color":          c("white"),
        "Cursor Color":        c("accent"),
        "Cursor Text Color":   c("black"),
        "Selection Color":     c("bg2", 0.5),
        "Selected Text Color": c("white"),
        "Link Color":          c("blue"),
        # ANSI 0-7 (normal)
        "Ansi 0 Color":  c("black"),
        "Ansi 1 Color":  c("red"),
        "Ansi 2 Color":  c("green"),
        "Ansi 3 Color":  c("yellow"),
        "Ansi 4 Color":  c("blue"),
        "Ansi 5 Color":  c("magenta"),
        "Ansi 6 Color":  c("blue"),     # no cyan in palette — use blue
        "Ansi 7 Color":  c("grey"),
        # ANSI 8-15 (bright)
        "Ansi 8 Color":  c("bg2"),
        "Ansi 9 Color":  c("red"),
        "Ansi 10 Color": c("green"),
        "Ansi 11 Color": c("yellow"),
        "Ansi 12 Color": c("accent"),
        "Ansi 13 Color": c("magenta"),
        "Ansi 14 Color": c("accent"),
        "Ansi 15 Color": c("white"),
    }

    # Duplicate each color as its own (Dark) variant so adaptive-color mode
    # gets the right values without needing a separate light-mode definition.
    dark_colors = {f"{k} (Dark)": v for k, v in colors.items()}

    return {
        "Guid":                         PROFILE_GUID,
        "Name":                         PROFILE_NAME,
        "Dynamic Profile Parent Name":  PARENT_PROFILE,
        **colors,
        **dark_colors,
    }


def main(palette_path: str, output_path: str):
    try:
        with open(palette_path) as f:
            palette = json.load(f)
    except Exception:
        palette = {}

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    profile = build_profile(palette)

    with open(output_path, "w") as f:
        json.dump({"Profiles": [profile]}, f, indent=2)
    print(f"Generated: {output_path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(
            "Usage: generate_iterm.py <palette.json> [output.json]",
            file=sys.stderr,
        )
        sys.exit(1)

    palette_file = sys.argv[1]
    output_file  = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
        DYNAMIC_PROFILES_DIR, "wallpaper.json"
    )
    main(palette_file, output_file)
