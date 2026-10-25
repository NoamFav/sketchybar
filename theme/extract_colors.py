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


# A cluster below this share of sampled pixels is treated as quantization
# noise (anti-aliasing blends, compression artifacts, stray specular pixels)
# and is excluded from accent/text/background selection entirely.
MIN_POP_FRAC = 0.003
# Population share at which a cluster gets full credit in vibrance/saturation
# scoring; below this its score is scaled down linearly. This stops a
# barely-present fleck from outranking a color that actually covers the image.
POP_FULL_CREDIT = 0.01
# A per-cluster floor just high enough to exclude 0-1 pixel quantization
# flukes (at the 120x120 sample size, ~2 pixels). Real noise-rejection
# happens at the hue-bucket TOTAL below — a smooth highlight (a lantern's
# glow shading orange -> gold -> white) gets sliced by quantization into many
# small same-hue slivers, each too small alone to pass MIN_POP_FRAC, but
# together clearly a real, visible feature of the image.
MIN_CLUSTER_FRAC = 2 / (120 * 120)


def extract_dominant(image_path, n=16):
    """Return [(r, g, b, population_fraction), ...] for the image's dominant clusters."""
    img = _open_image(image_path)
    img = img.resize((120, 120), Image.LANCZOS)
    q = img.quantize(colors=n, method=Image.Quantize.FASTOCTREE)
    p = q.getpalette()[:n * 3]
    total = img.size[0] * img.size[1]
    pop = {idx: 0 for idx in range(n)}
    for count, idx in q.getcolors(maxcolors=total):
        pop[idx] = count
    return [
        (p[i * 3], p[i * 3 + 1], p[i * 3 + 2], pop[i] / total)
        for i in range(n)
    ]


def pop_weight(frac):
    """0..1 credit for a cluster's prominence, capped at POP_FULL_CREDIT."""
    return min(1.0, frac / POP_FULL_CREDIT)


def build_palette(image_path):
    dominant = extract_dominant(image_path, 16)
    dominant.sort(key=lambda c: luminance(*c[:3]))
    raw = [c[:3] for c in dominant]
    pop = [c[3] for c in dominant]
    hsv_all = [to_hsv(*c) for c in raw]

    n = len(raw)

    # Clusters with enough real presence in the image to be trusted as a
    # background, text, or accent color — everything else is noise.
    significant = [i for i in range(n) if pop[i] >= MIN_POP_FRAC]
    if not significant:
        significant = list(range(n))  # degenerate image: nothing passes, use it all

    # ── Backgrounds ────────────────────────────────────────────────────────────
    bg_idx = min(significant, key=lambda i: luminance(*raw[i]))
    bg = darken_to(*raw[bg_idx], target_lum=0.025)
    bg_lum = luminance(*bg)
    bg_h, bg_s, bg_v = to_hsv(*bg)

    # bg1/bg2: prefer neutral (low-saturation) dark clusters so warm image
    # reflections don't bleed into bracket/chip backgrounds.
    dark_neutral = sorted(
        significant,
        key=lambda i: (hsv_all[i][1], -luminance(*raw[i]))  # low-sat first, then darkest
    )
    bg1_raw = darken_to(*raw[dark_neutral[min(1, len(dark_neutral)-1)]], target_lum=0.06)
    bg1 = tuple(max(bg[i], bg1_raw[i]) for i in range(3))

    bg2_raw = darken_to(*raw[dark_neutral[min(2, len(dark_neutral)-1)]], target_lum=0.10)
    bg2 = tuple(max(bg1[i], bg2_raw[i]) for i in range(3))

    # ── Foreground (text) ───────────────────────────────────────────────────────
    # Prefer a neutral (low-saturation) bright cluster so text doesn't take the
    # hue of a colored light (e.g. amber glow in a dark scene). Population-
    # filtered so a single stray near-white pixel can't become the text color.
    neutral_bright = [
        i for i in significant
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

    # ── Palette colors: only ever colors actually in the wallpaper ─────────────
    # No target hues, no "find something red-ish" matching, no synthesizing
    # anything the photo doesn't have. Classify each real color by which
    # named hue it happens to sit closest to — the names are just labels for
    # "the wallpaper's own warmest color", "its own greenest color", etc,
    # never a target to search outward from. A wallpaper that's mostly
    # orange/yellow with one note of blue ends up with several warm slots
    # and exactly one (correctly minor) blue slot — not six evenly-spaced
    # invented hues.
    #
    # A bucket is trusted once its members' COMBINED population clears
    # MIN_POP_FRAC, not any single member alone — see MIN_CLUSTER_FRAC above
    # for why: a gradient highlight quantizes into many small same-hue
    # pieces that only add up to a real feature together.
    colorful = [
        i for i in range(n)
        if pop[i] >= MIN_CLUSTER_FRAC and hsv_all[i][2] > 0.12 and hsv_all[i][1] > 0.20
    ]
    prominence = lambda i: hsv_all[i][1] * hsv_all[i][2] * pop_weight(pop[i])

    hue_centers = {
        "red": 0, "orange": 25, "yellow": 55,
        "green": 120, "blue": 220, "magenta": 295,
    }
    buckets = {name: [] for name in hue_centers}
    for i in colorful:
        nearest_name = min(hue_centers, key=lambda name: hue_dist(hsv_all[i][0], hue_centers[name]))
        buckets[nearest_name].append(i)
    # Within a bucket, the representative color is whichever member actually
    # covers the most of the image, not whichever is brightest. `prominence`
    # above is capped at 1% population, which lets a tiny blown-out
    # highlight (a lantern's hottest point, under 1% of the pixels) outrank
    # a color that fills a tenth of the frame just because it's more vivid —
    # exactly backwards for "what IS the orange/red/etc. of this wallpaper."
    representativeness = lambda i: pop[i] * hsv_all[i][1]
    for name in buckets:
        buckets[name].sort(key=representativeness, reverse=True)

    # For the "reuse the wallpaper's overall dominant color" fallback below,
    # stick to individually-significant clusters only — a bucket that's
    # empty shouldn't get filled with some other hue's obscure gradient
    # sliver, only its genuinely prominent color.
    candidates = [i for i in colorful if pop[i] >= MIN_POP_FRAC]
    by_vibrance = sorted(candidates, key=prominence, reverse=True)

    assigned = {}
    for name in hue_centers:
        bucket_pop = sum(pop[i] for i in buckets[name])
        if buckets[name] and bucket_pop >= MIN_POP_FRAC:
            assigned[name] = lift_accent(*raw[buckets[name][0]], bg_lum, min_cr=2.5)
        elif by_vibrance:
            # Nothing in the wallpaper is actually closest to this hue —
            # reuse its single most prominent real color overall instead of
            # reaching for some other hue's cluster just to fill the slot.
            assigned[name] = lift_accent(*raw[by_vibrance[0]], bg_lum, min_cr=2.5)
        else:
            assigned[name] = grey

    accent = (
        lift_accent(*raw[by_vibrance[0]], bg_lum, min_cr=2.5)
        if by_vibrance else grey
    )

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
