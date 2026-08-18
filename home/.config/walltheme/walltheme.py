#!/usr/bin/env python3

from PIL import Image
from pathlib import Path
import colorsys
import json
import math
import sys


# =========================================================
# CONFIGURATION
# =========================================================

BASE = Path.home() / ".config" / "walltheme"

OUTPUT = BASE / "current.json"

IMAGE_SIZE = 256
COLOR_COUNT = 16


# =========================================================
# BASIC COLOR UTILITIES
# =========================================================

def rgb_to_hex(rgb):
    return "#{:02x}{:02x}{:02x}".format(*rgb)


def hex_to_rgb(value):
    value = value.lstrip("#")

    return tuple(
        int(value[i:i + 2], 16)
        for i in (0, 2, 4)
    )


def clamp(value, minimum=0, maximum=255):
    return max(
        minimum,
        min(maximum, int(value))
    )


def brightness(rgb):
    """
    Perceived brightness.
    Returns a value between 0 and 255.
    """

    r, g, b = rgb

    return (
        0.2126 * r +
        0.7152 * g +
        0.0722 * b
    )


def saturation(rgb):
    """
    HSV saturation.
    Returns a value between 0 and 1.
    """

    r, g, b = [
        x / 255
        for x in rgb
    ]

    return colorsys.rgb_to_hsv(
        r,
        g,
        b
    )[1]


def hue(rgb):
    """
    HSV hue.
    Returns a value between 0 and 1.
    """

    r, g, b = [
        x / 255
        for x in rgb
    ]

    return colorsys.rgb_to_hsv(
        r,
        g,
        b
    )[0]


def distance(c1, c2):
    """
    Euclidean RGB distance.
    """

    return math.sqrt(
        sum(
            (a - b) ** 2
            for a, b in zip(c1, c2)
        )
    )


def mix(c1, c2, amount):
    """
    Mix two RGB colors.

    amount:
        0.0 = c1
        1.0 = c2
    """

    return tuple(
        clamp(
            c1[i] * (1 - amount) +
            c2[i] * amount
        )
        for i in range(3)
    )


def lighten(rgb, amount):
    return mix(
        rgb,
        (255, 255, 255),
        amount
    )


def darken(rgb, amount):
    return mix(
        rgb,
        (0, 0, 0),
        amount
    )


# =========================================================
# WCAG CONTRAST
# =========================================================

def relative_luminance(rgb):
    """
    Calculate WCAG relative luminance.
    """

    values = []

    for value in rgb:

        value = value / 255

        if value <= 0.03928:

            value = (
                value / 12.92
            )

        else:

            value = (
                (value + 0.055) / 1.055
            ) ** 2.4

        values.append(value)

    r, g, b = values

    return (
        0.2126 * r +
        0.7152 * g +
        0.0722 * b
    )


def contrast_ratio(c1, c2):
    """
    WCAG contrast ratio between two colors.
    """

    l1 = relative_luminance(c1)
    l2 = relative_luminance(c2)

    lighter = max(l1, l2)
    darker = min(l1, l2)

    return (
        (lighter + 0.05) /
        (darker + 0.05)
    )


# =========================================================
# ACCENT GENERATION
# =========================================================

def make_dark_accent(rgb):
    """
    Preserve the wallpaper's hue while forcing the
    resulting color into a dark, saturated range.

    Used for surfaces sitting directly against
    bright wallpapers.
    """

    h = hue(rgb)

    s = max(
        saturation(rgb),
        0.55
    )

    v = 0.32

    r, g, b = colorsys.hsv_to_rgb(
        h,
        min(s, 0.90),
        v
    )

    return (
        int(r * 255),
        int(g * 255),
        int(b * 255)
    )


def make_bright_accent(rgb):
    """
    Preserve the wallpaper's hue while forcing the
    resulting color into a bright, saturated range.

    Used for text/icons on dark surfaces.
    """

    h = hue(rgb)

    s = max(
        saturation(rgb),
        0.55
    )

    v = 0.85

    r, g, b = colorsys.hsv_to_rgb(
        h,
        min(s, 0.90),
        v
    )

    return (
        int(r * 255),
        int(g * 255),
        int(b * 255)
    )


def boost_saturation(rgb, amount=0.15):
    """
    Increase saturation while preserving hue.
    """

    h = hue(rgb)

    s = min(
        1.0,
        saturation(rgb) + amount
    )

    v = max(
        brightness(rgb) / 255,
        0.35
    )

    r, g, b = colorsys.hsv_to_rgb(
        h,
        s,
        v
    )

    return (
        int(r * 255),
        int(g * 255),
        int(b * 255)
    )


def shift_hue(rgb, amount):
    """
    Shift hue while preserving saturation/value.
    """

    h = hue(rgb)

    s = saturation(rgb)

    v = max(
        brightness(rgb) / 255,
        0.35
    )

    r, g, b = colorsys.hsv_to_rgb(
        (h + amount) % 1.0,
        s,
        v
    )

    return (
        int(r * 255),
        int(g * 255),
        int(b * 255)
    )


# =========================================================
# IMAGE LOADING
# =========================================================

def load_wallpaper(path):

    image = Image.open(
        path
    ).convert("RGB")

    image.thumbnail(
        (
            IMAGE_SIZE,
            IMAGE_SIZE
        )
    )

    return image


# =========================================================
# COLOR EXTRACTION
# =========================================================

def extract_colors(image):

    quantized = image.quantize(
        colors=COLOR_COUNT,
        method=Image.Quantize.MEDIANCUT
    )

    palette = quantized.getpalette()

    color_counts = (
        quantized.getcolors()
    )

    colors = []

    for count, index in color_counts:

        rgb = (
            palette[index * 3],
            palette[index * 3 + 1],
            palette[index * 3 + 2]
        )

        colors.append({
            "rgb": rgb,
            "count": count
        })

    colors.sort(
        key=lambda x: x["count"],
        reverse=True
    )

    return colors


# =========================================================
# RAW COLOR SELECTION
# =========================================================

def select_background(colors):

    dark = [
        c
        for c in colors
        if brightness(c["rgb"]) < 100
    ]

    if dark:

        return min(
            dark,
            key=lambda c: brightness(
                c["rgb"]
            )
        )["rgb"]

    return min(
        colors,
        key=lambda c: brightness(
            c["rgb"]
        )
    )["rgb"]


def select_foreground(colors):

    bright = [
        c
        for c in colors
        if brightness(c["rgb"]) > 150
    ]

    if bright:

        return max(
            bright,
            key=lambda c: brightness(
                c["rgb"]
            )
        )["rgb"]

    return (
        235,
        235,
        235
    )


def select_accent(colors):

    candidates = []

    for color in colors:

        rgb = color["rgb"]

        b = brightness(rgb)
        s = saturation(rgb)

        # Ignore almost-black and almost-white colors.
        if b < 35 or b > 230:
            continue

        # Ignore extremely desaturated colors.
        if s < 0.15:
            continue

        score = (
            s * 2.5 +
            color["count"] / 10000
        )

        candidates.append(
            (
                score,
                rgb
            )
        )

    if candidates:

        candidates.sort(
            key=lambda x: x[0],
            reverse=True
        )

        return candidates[0][1]

    # Fallback
    return (
        80,
        120,
        120
    )


def select_secondary(
    colors,
    accent
):

    candidates = []

    for color in colors:

        rgb = color["rgb"]

        if distance(
            rgb,
            accent
        ) < 70:

            continue

        b = brightness(rgb)
        s = saturation(rgb)

        if b < 35 or b > 230:
            continue

        if s < 0.15:
            continue

        score = (
            s +
            color["count"] / 20000
        )

        candidates.append(
            (
                score,
                rgb
            )
        )

    if candidates:

        candidates.sort(
            key=lambda x: x[0],
            reverse=True
        )

        return candidates[0][1]

    return accent


# =========================================================
# CONTRAST-AWARE ACCENT SELECTION
# =========================================================

def choose_contrasting_accent(
    colors,
    reference,
    prefer_dark
):
    """
    Choose a wallpaper-derived accent that has enough
    contrast against the reference color.

    Used primarily for elements directly touching
    the wallpaper, such as active workspaces.
    """

    candidates = []

    for color in colors:

        rgb = color["rgb"]

        s = saturation(rgb)
        b = brightness(rgb)

        if s < 0.25:
            continue

        if prefer_dark:

            if b > 130:
                continue

        else:

            if b < 100:
                continue

        ratio = contrast_ratio(
            rgb,
            reference
        )

        score = (
            ratio * 3.0 +
            s * 2.0 +
            color["count"] / 10000
        )

        candidates.append(
            (
                score,
                ratio,
                rgb
            )
        )

    candidates.sort(
        key=lambda x: x[0],
        reverse=True
    )

    # WCAG AA-ish threshold.
    for _, ratio, rgb in candidates:

        if ratio >= 4.0:
            return rgb

    # No extracted color was suitable.
    # Synthesize an accent from the most saturated
    # wallpaper color.
    source = max(
        colors,
        key=lambda c: saturation(
            c["rgb"]
        )
    )["rgb"]

    if prefer_dark:

        return make_dark_accent(
            source
        )

    return make_bright_accent(
        source
    )


# =========================================================
# SEMANTIC THEME GENERATION
# =========================================================

def build_theme(colors):

    # -----------------------------------------------------
    # DETERMINE WALLPAPER LIGHTNESS
    # -----------------------------------------------------

    wallpaper_base = max(
        colors,
        key=lambda c: c["count"]
    )["rgb"]

    wallpaper_is_light = (
        brightness(
            wallpaper_base
        ) > 128
    )

    # -----------------------------------------------------
    # FIXED DARK UI FOUNDATION
    #
    # Wallpaper brightness is NOT allowed to turn the
    # desktop UI into a light/low-contrast interface.
    # -----------------------------------------------------

    background = (
        10,
        13,
        15
    )

    surface = (
        16,
        20,
        22
    )

    surface_alt = (
        24,
        29,
        31
    )

    # -----------------------------------------------------
    # ACCENT FOR SURFACES TOUCHING WALLPAPER
    #
    # Example:
    # active workspace button
    #
    # A light wallpaper gets a dark accent.
    # A dark wallpaper gets a bright accent.
    # -----------------------------------------------------

    if wallpaper_is_light:

        accent_surface = (
            choose_contrasting_accent(
                colors,
                wallpaper_base,
                prefer_dark=True
            )
        )

    else:

        accent_surface = (
            choose_contrasting_accent(
                colors,
                wallpaper_base,
                prefer_dark=False
            )
        )

    # Guarantee sufficient contrast against wallpaper.
    if contrast_ratio(
        accent_surface,
        wallpaper_base
    ) < 4.0:

        if wallpaper_is_light:

            accent_surface = (
                35,
                65,
                68
            )

        else:

            accent_surface = (
                100,
                180,
                180
            )

    # -----------------------------------------------------
    # PRIMARY ACCENT FOR TEXT / ICONS
    # -----------------------------------------------------

    raw_accent = select_accent(
        colors
    )

    accent = make_bright_accent(
        raw_accent
    )

    # Ensure readability against dark surfaces.
    if contrast_ratio(
        accent,
        surface
    ) < 4.5:

        accent = (
            210,
            225,
            220
        )

    # -----------------------------------------------------
    # SECONDARY ACCENT
    # -----------------------------------------------------

    raw_secondary = select_secondary(
        colors,
        raw_accent
    )

    accent_secondary = (
        make_bright_accent(
            raw_secondary
        )
    )

    if contrast_ratio(
        accent_secondary,
        surface
    ) < 4.5:

        accent_secondary = (
            180,
            210,
            205
        )

    # -----------------------------------------------------
    # TERTIARY ACCENT
    # -----------------------------------------------------

    accent_tertiary = shift_hue(
        accent,
        0.08
    )

    accent_tertiary = boost_saturation(
        accent_tertiary,
        0.10
    )

    if contrast_ratio(
        accent_tertiary,
        surface
    ) < 4.5:

        accent_tertiary = (
            195,
            215,
            210
        )

    # -----------------------------------------------------
    # HOVER / ACTIVE
    # -----------------------------------------------------

    accent_hover = lighten(
        accent,
        0.12
    )

    accent_active = darken(
        accent_surface,
        0.12
    )

    # -----------------------------------------------------
    # TEXT
    #
    # Fixed because readability is more important than
    # wallpaper matching.
    # -----------------------------------------------------

    foreground = (
        242,
        244,
        242
    )

    muted = (
        175,
        183,
        181
    )

    # -----------------------------------------------------
    # BORDER
    #
    # Wallpaper-derived, but intentionally visible.
    # -----------------------------------------------------

    border = accent_surface

    # -----------------------------------------------------
    # SELECTION
    # -----------------------------------------------------

    selection = mix(
        accent,
        surface_alt,
        0.55
    )

    # -----------------------------------------------------
    # SEMANTIC COLORS
    #
    # These retain their meaning regardless of wallpaper.
    # -----------------------------------------------------

    warning = (
        245,
        190,
        70
    )

    error = (
        240,
        90,
        90
    )

    success = (
        100,
        210,
        140
    )

    # -----------------------------------------------------
    # FINAL THEME
    # -----------------------------------------------------

    return {

        "mode": "dark",

        # UI foundation
        "background":
            rgb_to_hex(
                background
            ),

        "surface":
            rgb_to_hex(
                surface
            ),

        "surface_alt":
            rgb_to_hex(
                surface_alt
            ),

        # Text
        "foreground":
            rgb_to_hex(
                foreground
            ),

        "muted":
            rgb_to_hex(
                muted
            ),

        # Borders
        "border":
            rgb_to_hex(
                border
            ),

        # Text/icon accents
        "accent":
            rgb_to_hex(
                accent
            ),

        "accent_hover":
            rgb_to_hex(
                accent_hover
            ),

        "accent_active":
            rgb_to_hex(
                accent_active
            ),

        "accent_secondary":
            rgb_to_hex(
                accent_secondary
            ),

        "accent_tertiary":
            rgb_to_hex(
                accent_tertiary
            ),

        # Surface accent
        "accent_surface":
            rgb_to_hex(
                accent_surface
            ),

        # Selection
        "selection":
            rgb_to_hex(
                selection
            ),

        # Semantic
        "warning":
            rgb_to_hex(
                warning
            ),

        "error":
            rgb_to_hex(
                error
            ),

        "success":
            rgb_to_hex(
                success
            ),

        # Absolute
        "black":
            "#000000",

        "white":
            "#ffffff"
    }


# =========================================================
# MAIN
# =========================================================

def main():

    if len(sys.argv) != 2:

        print(
            "Usage: walltheme <wallpaper>"
        )

        sys.exit(1)

    wallpaper = Path(
        sys.argv[1]
    ).expanduser()

    if not wallpaper.exists():

        print(
            f"Wallpaper not found: {wallpaper}"
        )

        sys.exit(1)

    if not wallpaper.is_file():

        print(
            f"Not a file: {wallpaper}"
        )

        sys.exit(1)

    print(
        f"Analyzing wallpaper:"
    )

    print(
        f"  {wallpaper}"
    )

    print()

    try:

        image = load_wallpaper(
            wallpaper
        )

        colors = extract_colors(
            image
        )

        theme = build_theme(
            colors
        )

    except Exception as error:

        print(
            f"Failed to generate theme:"
        )

        print(
            f"  {error}"
        )

        sys.exit(1)

    # -----------------------------------------------------
    # SAVE
    # -----------------------------------------------------

    BASE.mkdir(
        parents=True,
        exist_ok=True
    )

    output = {
        "wallpaper": str(
            wallpaper
        ),
        **theme,
        "colors": [
            {
                "color":
                    rgb_to_hex(
                        color["rgb"]
                    ),

                "count":
                    color["count"],

                "brightness":
                    round(
                        brightness(
                            color["rgb"]
                        ),
                        2
                    ),

                "saturation":
                    round(
                        saturation(
                            color["rgb"]
                        ),
                        3
                    )
            }
            for color in colors
        ]
    }

    with open(
        OUTPUT,
        "w"
    ) as file:

        json.dump(
            output,
            file,
            indent=4
        )

    # -----------------------------------------------------
    # OUTPUT
    # -----------------------------------------------------

    print(
        "Generated theme:"
    )

    print()

    important = [
        "background",
        "surface",
        "surface_alt",
        "foreground",
        "muted",
        "border",
        "accent",
        "accent_secondary",
        "accent_tertiary",
        "accent_surface"
    ]

    for key in important:

        print(
            f"  {key:<20} "
            f"{output[key]}"
        )

    print()

    print(
        f"Saved → {OUTPUT}"
    )


if __name__ == "__main__":
    main()
