#!/usr/bin/env python3
"""Extract a wallpaper-derived color palette and output JSON for sketchybar."""

import sys
import json
import colorsys
from PIL import Image


# ── Color math helpers ─────────────────────────────────────────────────────────

def srgb_linear(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def luminance(r, g, b):
    return 0.2126 * srgb_linear(r) + 0.7152 * srgb_linear(g) + 0.0722 * srgb_linear(b)

def contrast(l1, l2):
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)

def to_hsv(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return h * 360, s, v

def from_hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h / 360, s, v)
    return int(r * 255), int(g * 255), int(b * 255)

def hue_dist(h1, h2):
    d = abs(h1 - h2)
    return min(d, 360 - d)

def darken_to(r, g, b, target_lum):
    if luminance(r, g, b) <= target_lum:
        return r, g, b
    h, s, v = to_hsv(r, g, b)
    for step in range(1, 20):
        v2 = v * (1 - step * 0.07)
        if v2 < 0:
            break
        nr, ng, nb = from_hsv(h, s, v2)
        if luminance(nr, ng, nb) <= target_lum:
            return nr, ng, nb
    return 15, 15, 22

def brighten_to(r, g, b, bg_lum, min_cr=4.5):
    if contrast(luminance(r, g, b), bg_lum) >= min_cr:
        return r, g, b
    h, s, v = to_hsv(r, g, b)
    for step in range(1, 15):
        v2 = min(1.0, v + step * 0.07)
        s2 = max(0.0, s - step * 0.04)
        nr, ng, nb = from_hsv(h, s2, v2)
        if contrast(luminance(nr, ng, nb), bg_lum) >= min_cr:
            return nr, ng, nb
    return 210, 215, 240

def lift_accent(r, g, b, bg_lum, min_cr=2.5):
    if contrast(luminance(r, g, b), bg_lum) >= min_cr:
        return r, g, b
    h, s, v = to_hsv(r, g, b)
    for step in range(1, 12):
        v2 = min(1.0, v + step * 0.08)
        nr, ng, nb = from_hsv(h, s, v2)
        if contrast(luminance(nr, ng, nb), bg_lum) >= min_cr:
            return nr, ng, nb
    return r, g, b

def synth_hue(target_hue, base_sat, base_val, bg_lum):
    """Generate a visible color at target_hue when the palette lacks one."""
    s = max(0.55, base_sat)
    v = max(0.60, base_val)
    r, g, b = from_hsv(target_hue, s, v)
    return lift_accent(r, g, b, bg_lum, min_cr=2.5)

def sketchybar_hex(r, g, b, alpha=255):
    return f"0x{alpha:02x}{r:02x}{g:02x}{b:02x}"


# ── Palette extraction ─────────────────────────────────────────────────────────

def _open_image(image_path):
    """Open image with Pillow, converting via ImageMagick if needed (e.g. HEIF)."""
    try:
        return Image.open(image_path).convert("RGB")
    except Exception:
        pass
    import subprocess, tempfile, os
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        tmp_path = tmp.name
    try:
        subprocess.run(
            ["magick", image_path, "-flatten", tmp_path],
            check=True, capture_output=True
        )
        return Image.open(tmp_path).convert("RGB")
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass


def extract_dominant(image_path, n=16):
    img = _open_image(image_path)
    img = img.resize((120, 120), Image.LANCZOS)
    q = img.quantize(colors=n, method=Image.Quantize.FASTOCTREE)
    p = q.getpalette()[:n * 3]
    return [(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]) for i in range(n)]


def build_palette(image_path):
    raw = extract_dominant(image_path, 16)
    raw.sort(key=lambda c: luminance(*c))
    hsv_all = [to_hsv(*c) for c in raw]

    n = len(raw)

    # ── Backgrounds ────────────────────────────────────────────────────────────
    bg = darken_to(*raw[0], target_lum=0.025)
    bg_lum = luminance(*bg)
    bg_h, bg_s, bg_v = to_hsv(*bg)

    # bg1/bg2: prefer neutral (low-saturation) dark clusters so warm image
    # reflections don't bleed into bracket/chip backgrounds.
    dark_neutral = sorted(
        range(n),
        key=lambda i: (hsv_all[i][1], -luminance(*raw[i]))  # low-sat first, then darkest
    )
    bg1_raw = darken_to(*raw[dark_neutral[min(1, n-1)]], target_lum=0.06)
    bg1 = tuple(max(bg[i], bg1_raw[i]) for i in range(3))

    bg2_raw = darken_to(*raw[dark_neutral[min(2, n-1)]], target_lum=0.10)
    bg2 = tuple(max(bg1[i], bg2_raw[i]) for i in range(3))

    # ── Foreground (text) ───────────────────────────────────────────────────────
    # Prefer a neutral (low-saturation) bright cluster so text doesn't take the
    # hue of a colored light (e.g. amber glow in a dark scene).
    neutral_bright = [
        i for i in range(n)
        if luminance(*raw[i]) > 0.25 and hsv_all[i][1] < 0.25
    ]
    if neutral_bright:
        fg_base = raw[neutral_bright[-1]]  # lightest neutral
    else:
        # No neutral bright cluster — synthesize near-white from the bg hue
        # (keeps a very faint tint of the scene without stealing accent colors)
        fg_base = from_hsv(bg_h, 0.06, 0.88)

    fg = brighten_to(*fg_base, bg_lum, min_cr=4.5)
    fg_lum = luminance(*fg)

    fh, fs, fv = to_hsv(*fg)
    grey = from_hsv(fh, min(fs, 0.12), fv * 0.52)
    grey = lift_accent(*grey, bg_lum, min_cr=2.0)

    # ── Accents (hue-based semantic assignment) ─────────────────────────────────
    # Exclude clusters already claimed as neutral-bright (fg candidates) so
    # saturated lights (amber, blue, etc.) land in accent slots, not text.
    candidates = [
        i for i, c in enumerate(raw)
        if luminance(*c) > bg_lum * 1.5 and hsv_all[i][1] > 0.20
    ]
    # For hue slot matching: sort by saturation (find the most "pure" hue match)
    by_sat = sorted(candidates, key=lambda i: hsv_all[i][1], reverse=True)
    # For the dominant accent: sort by vibrance (sat × val) so we pick the
    # brightest saturated color, not the darkest most-saturated one.
    by_vibrance = sorted(candidates, key=lambda i: hsv_all[i][1] * hsv_all[i][2], reverse=True)

    base_sat = hsv_all[by_sat[0]][1] if by_sat else 0.65
    base_val = max(0.60, hsv_all[by_sat[0]][2] if by_sat else 0.70)

    hue_slots = {
        "red":     (0,   30),
        "orange":  (25,  20),
        "yellow":  (55,  22),
        "green":   (120, 40),
        "blue":    (220, 45),
        "magenta": (295, 38),
    }

    assigned = {}
    used = set()

    for name, (center, half_w) in hue_slots.items():
        hits = [
            i for i in by_sat
            if hue_dist(hsv_all[i][0], center) <= half_w and i not in used
        ]
        if hits:
            used.add(hits[0])
            assigned[name] = lift_accent(*raw[hits[0]], bg_lum, min_cr=2.5)
        else:
            assigned[name] = synth_hue(center, base_sat, base_val, bg_lum)

    # Dominant accent = most vibrant cluster (bright + saturated = "hero" color)
    accent = assigned["blue"]
    if by_vibrance:
        accent = lift_accent(*raw[by_vibrance[0]], bg_lum, min_cr=2.5)

    return {
        "black":        sketchybar_hex(*bg),
        "white":        sketchybar_hex(*fg),
        "grey":         sketchybar_hex(*grey),
        "red":          sketchybar_hex(*assigned["red"]),
        "green":        sketchybar_hex(*assigned["green"]),
        "blue":         sketchybar_hex(*assigned["blue"]),
        "yellow":       sketchybar_hex(*assigned["yellow"]),
        "orange":       sketchybar_hex(*assigned["orange"]),
        "magenta":      sketchybar_hex(*assigned["magenta"]),
        "bg1":          sketchybar_hex(*bg1),
        "bg2":          sketchybar_hex(*bg2),
        "bar_bg":       sketchybar_hex(*bg, alpha=0),
        "bar_border":   sketchybar_hex(*bg2),
        "popup_bg":     sketchybar_hex(*bg1, alpha=0xc0),
        "popup_border": sketchybar_hex(*grey),
        "accent":       sketchybar_hex(*accent),
    }


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: extract_colors.py <image_path>", file=sys.stderr)
        sys.exit(1)
    result = build_palette(sys.argv[1])
    print(json.dumps(result, indent=2))
