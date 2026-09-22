#!/usr/bin/env python3

from PIL import Image
from pathlib import Path
import colorsys
import hashlib
import json
import math
import subprocess
import sys
import tempfile


# =========================================================
# CONFIGURATION
# =========================================================

BASE = Path.home() / ".config" / "walltheme"

OUTPUT = BASE / "current.json"

IMAGE_SIZE = 256
COLOR_COUNT = 16

# Number of representative frames to use when
# generating a palette from an animated GIF.
GIF_FRAME_COUNT = 5

# Each sampled GIF frame receives equal weight during
# palette extraction.
GIF_ANALYSIS_SIZE = 128

# Video wallpaper formats supported by Walltheme.
VIDEO_EXTENSIONS = {
    ".mp4",
    ".webm",
    ".mkv",
}

# Video frames are kept in the user's local cache rather
# than inside the dotfiles/config tree.
VIDEO_CACHE_ROOT = (
    Path.home()
    / ".cache"
    / "walltheme"
    / "video-frames"
)

VIDEO_ANALYSIS_SIZE = 128

# Increment this when the cache structure or extraction
# strategy changes.
VIDEO_CACHE_VERSION = 1

# Static presentation image used by Hyprlock and SDDM.
PRESENTATION_DIR = BASE / "cache"
PRESENTATION_OUTPUT = (
    PRESENTATION_DIR
    / "current-presentation.png"
)


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

def adjust_contrast_preserve_hue(
    rgb,
    reference,
    minimum_ratio=4.5,
):
    """
    Preserve the wallpaper-derived hue and saturation.

    The original extracted color is always preferred. When
    contrast is insufficient, only HSV value is adjusted.

    If no value at the original hue/saturation can satisfy the
    requirement, return the same-hue/same-saturation variant
    with the strongest available contrast.
    """

    if contrast_ratio(
        rgb,
        reference
    ) >= minimum_ratio:
        return rgb

    h = hue(rgb)
    s = saturation(rgb)
    original_v = brightness(rgb) / 255

    best = None
    best_change = float("inf")

    for step in range(101):

        v = step / 100

        r, g, b = colorsys.hsv_to_rgb(
            h,
            s,
            v
        )

        candidate = (
            int(round(r * 255)),
            int(round(g * 255)),
            int(round(b * 255))
        )

        ratio = contrast_ratio(
            candidate,
            reference
        )

        if ratio < minimum_ratio:
            continue

        change = abs(
            v - original_v
        )

        if change < best_change:
            best = candidate
            best_change = change

    if best is not None:
        return best

    # The requested contrast is impossible at this hue and
    # saturation. Stay faithful to the wallpaper and return the
    # strongest contrast available along the same HSV line.
    best = rgb
    best_ratio = contrast_ratio(
        rgb,
        reference
    )

    for step in range(101):

        v = step / 100

        r, g, b = colorsys.hsv_to_rgb(
            h,
            s,
            v
        )

        candidate = (
            int(round(r * 255)),
            int(round(g * 255)),
            int(round(b * 255))
        )

        ratio = contrast_ratio(
            candidate,
            reference
        )

        if ratio > best_ratio:
            best = candidate
            best_ratio = ratio

    return best


# =========================================================
# VIDEO HELPERS
# =========================================================

def video_duration(path):
    """
    Return the duration of a video in seconds.
    """

    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        capture_output=True,
        text=True,
        check=True,
    )

    try:
        duration = float(
            result.stdout.strip()
        )
    except ValueError as error:
        raise RuntimeError(
            "Could not determine video duration."
        ) from error

    if not math.isfinite(duration) or duration <= 0:
        raise RuntimeError(
            "Video duration is invalid."
        )

    return duration


def video_cache_info(path):
    """
    Build the local cache paths and source identity for
    a video wallpaper.
    """

    path = path.resolve()
    stat = path.stat()

    identity = (
        f"{path}\n"
        f"{stat.st_mtime_ns}\n"
        f"{stat.st_size}"
    ).encode()

    cache_key = hashlib.sha256(
        identity
    ).hexdigest()[:24]

    directory = (
        VIDEO_CACHE_ROOT
        / cache_key
    )

    return {
        "key": cache_key,
        "directory": directory,
        "first": directory / "first.png",
        "middle": directory / "middle.png",
        "metadata": directory / "metadata.json",
        "path": path,
        "mtime_ns": stat.st_mtime_ns,
        "size": stat.st_size,
    }


def video_cache_valid(path):
    """
    Return True when both cached frames belong to the
    exact current version of the source video.
    """

    info = video_cache_info(path)

    if not (
        info["first"].is_file()
        and info["middle"].is_file()
        and info["metadata"].is_file()
    ):
        return False

    try:
        metadata = json.loads(
            info["metadata"].read_text()
        )
    except (
        OSError,
        ValueError,
    ):
        return False

    return (
        metadata.get("version")
        == VIDEO_CACHE_VERSION
        and metadata.get("path")
        == str(info["path"])
        and metadata.get("mtime_ns")
        == info["mtime_ns"]
        and metadata.get("size")
        == info["size"]
    )


def extract_video_frame(
    path,
    timestamp,
    output,
):
    """
    Extract one video frame with FFmpeg.
    """

    output.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-ss",
            f"{timestamp:.6f}",
            "-i",
            str(path),
            "-map",
            "0:v:0",
            "-frames:v",
            "1",
            "-an",
            str(output),
        ],
        check=True,
    )

    if not output.is_file():
        raise RuntimeError(
            "FFmpeg did not produce the requested frame."
        )


def prepare_video_frames(path):
    """
    Return the cached first and middle frames.

    On a cache miss, extract both frames once and store
    them locally for future wallpaper changes.
    """

    info = video_cache_info(path)

    if video_cache_valid(path):
        return (
            info["first"],
            info["middle"],
        )

    VIDEO_CACHE_ROOT.mkdir(
        parents=True,
        exist_ok=True,
    )

    duration = video_duration(
        path
    )

    # Keep the middle frame away from the exact EOF.
    middle_timestamp = min(
        duration * 0.5,
        max(duration - 0.001, 0),
    )

    with tempfile.TemporaryDirectory(
        dir=VIDEO_CACHE_ROOT,
        prefix=f".{info['key']}-",
    ) as temporary:

        temporary_dir = Path(
            temporary
        )

        first_temp = (
            temporary_dir
            / "first.png"
        )

        middle_temp = (
            temporary_dir
            / "middle.png"
        )

        metadata_temp = (
            temporary_dir
            / "metadata.json"
        )

        extract_video_frame(
            path,
            0.0,
            first_temp,
        )

        extract_video_frame(
            path,
            middle_timestamp,
            middle_temp,
        )

        metadata_temp.write_text(
            json.dumps(
                {
                    "version":
                        VIDEO_CACHE_VERSION,
                    "path":
                        str(info["path"]),
                    "mtime_ns":
                        info["mtime_ns"],
                    "size":
                        info["size"],
                    "duration":
                        duration,
                },
                indent=2,
            )
            + "\n"
        )

        # Replace any stale cache atomically at directory level.
        if info["directory"].exists():
            shutil.rmtree(
                info["directory"]
            )

        temporary_dir.rename(
            info["directory"]
        )

    return (
        info["first"],
        info["middle"],
    )


def create_presentation_frame(path):
    """
    Create a static presentation image.

    Static images are returned unchanged.

    GIFs use their middle frame.

    Videos use the cached middle frame.
    """

    extension = path.suffix.lower()

    if extension not in {
        ".gif",
        *VIDEO_EXTENSIONS,
    }:
        return path

    PRESENTATION_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    # -----------------------------------------------------
    # GIF
    # -----------------------------------------------------

    if extension == ".gif":

        image = Image.open(
            path
        )

        try:
            if not getattr(
                image,
                "is_animated",
                False,
            ):
                return path

            frame_count = getattr(
                image,
                "n_frames",
                1,
            )

            frame_index = round(
                (frame_count - 1) * 0.5
            )

            image.seek(
                frame_index
            )

            frame = image.convert(
                "RGB"
            )

            temporary = (
                PRESENTATION_OUTPUT
                .with_suffix(
                    ".tmp.png"
                )
            )

            frame.save(
                temporary,
                format="PNG",
            )

            temporary.replace(
                PRESENTATION_OUTPUT
            )

        finally:
            image.close()

        return PRESENTATION_OUTPUT

    # -----------------------------------------------------
    # VIDEO
    # -----------------------------------------------------

    _first_frame, middle_frame = (
        prepare_video_frames(
            path
        )
    )

    temporary = (
        PRESENTATION_OUTPUT
        .with_suffix(
            ".tmp.png"
        )
    )

    Image.open(
        middle_frame
    ).save(
        temporary,
        format="PNG",
    )

    temporary.replace(
        PRESENTATION_OUTPUT
    )

    return PRESENTATION_OUTPUT


# =========================================================
# IMAGE LOADING
# =========================================================

def load_wallpaper(path):
    """
    Load a wallpaper for palette extraction.

    Static images follow the original path.

    Animated GIFs are sampled at evenly distributed
    points in the animation.

    Videos are sampled at evenly distributed timestamps.
    """

    extension = path.suffix.lower()

    # -----------------------------------------------------
    # VIDEO
    # -----------------------------------------------------

    if extension in VIDEO_EXTENSIONS:

        first_frame, middle_frame = (
            prepare_video_frames(
                path
            )
        )

        frames = []

        for frame_path in (
            first_frame,
            middle_frame,
        ):

            frame = Image.open(
                frame_path
            ).convert(
                "RGB"
            )

            frame = frame.resize(
                (
                    VIDEO_ANALYSIS_SIZE,
                    VIDEO_ANALYSIS_SIZE,
                ),
                Image.Resampling.LANCZOS,
            )

            frames.append(
                frame
            )

        analysis = Image.new(
            "RGB",
            (
                VIDEO_ANALYSIS_SIZE,
                VIDEO_ANALYSIS_SIZE * 2,
            ),
        )

        for position, frame in enumerate(
            frames
        ):

            analysis.paste(
                frame,
                (
                    0,
                    position * VIDEO_ANALYSIS_SIZE,
                ),
            )

            frame.close()

        return analysis

    # -----------------------------------------------------
    # IMAGE / GIF
    # -----------------------------------------------------

    image = Image.open(path)

    # -----------------------------------------------------
    # STATIC IMAGE
    # -----------------------------------------------------

    if not getattr(
        image,
        "is_animated",
        False,
    ):

        image = image.convert(
            "RGB"
        )

        image.thumbnail(
            (
                IMAGE_SIZE,
                IMAGE_SIZE,
            )
        )

        return image

    # -----------------------------------------------------
    # ANIMATED GIF
    # -----------------------------------------------------

    frame_count = getattr(
        image,
        "n_frames",
        1,
    )

    sample_count = min(
        GIF_FRAME_COUNT,
        frame_count,
    )

    if sample_count == 1:
        indices = [0]
    else:
        indices = [
            round(
                i * (frame_count - 1)
                / (sample_count - 1)
            )
            for i in range(
                sample_count
            )
        ]

    frames = []

    for index in indices:

        image.seek(
            index
        )

        frame = image.convert(
            "RGB"
        )

        frame = frame.resize(
            (
                GIF_ANALYSIS_SIZE,
                GIF_ANALYSIS_SIZE,
            ),
            Image.Resampling.LANCZOS,
        )

        frames.append(
            frame.copy()
        )

    image.close()

    # Stack all sampled frames vertically.
    # Every frame has identical dimensions, so every
    # frame contributes the same number of pixels.
    analysis = Image.new(
        "RGB",
        (
            GIF_ANALYSIS_SIZE,
            GIF_ANALYSIS_SIZE * len(frames),
        ),
    )

    for position, frame in enumerate(
        frames
    ):

        analysis.paste(
            frame,
            (
                0,
                position * GIF_ANALYSIS_SIZE,
            )
        )

        frame.close()

    return analysis


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

        s = saturation(rgb)

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

    return colors[0]["rgb"]


def select_secondary(
    colors,
    accent,
    additional_avoid=(),
):
    """
    Select another actual wallpaper-derived color.

    Color distance is a preference rather than a hard cutoff,
    so monochromatic wallpapers can still provide several
    related shades.
    """

    avoid = [
        accent,
        *additional_avoid,
    ]

    candidates = []

    for color in colors:

        rgb = color["rgb"]

        if rgb in avoid:
            continue

        s = saturation(rgb)

        nearest_distance = min(
            distance(
                rgb,
                other
            )
            for other in avoid
        )

        score = (
            nearest_distance / 255 * 2.0 +
            s * 1.5 +
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
    prefer_dark,
    minimum_ratio=4.0,
):
    """
    Choose an actual wallpaper-derived color with useful
    contrast against the reference.

    Saturation is never required. Neutral wallpaper colors are
    valid accents for neutral wallpapers.

    Existing extracted colors are always preferred over
    synthesized colors.
    """

    candidates = [
        color
        for color in colors
        if 35 <= brightness(color["rgb"]) <= 230
    ]

    if not candidates:
        return colors[0]["rgb"]

    valid = [
        color
        for color in candidates
        if contrast_ratio(
            color["rgb"],
            reference
        ) >= minimum_ratio
    ]

    pool = (
        valid
        if valid
        else candidates
    )

    if prefer_dark:

        return min(
            pool,
            key=lambda color: (
                brightness(color["rgb"]),
                -saturation(color["rgb"]),
                -color["count"],
            )
        )["rgb"]

    return max(
        pool,
        key=lambda color: (
            brightness(color["rgb"]),
            saturation(color["rgb"]),
            color["count"],
        )
    )["rgb"]


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
    # ACCENT FOR UI SURFACES / BORDERS
    #
    # This color is used by Waybar, Hyprland borders and
    # Ghostty UI elements, so its contrast is evaluated
    # against the dark UI rather than the wallpaper.
    #
    # The color itself still comes from the wallpaper palette.
    # -----------------------------------------------------

    accent_surface = choose_contrasting_accent(
        colors,
        surface,
        prefer_dark=wallpaper_is_light,
        minimum_ratio=3.0
    )

    # -----------------------------------------------------
    # PRIMARY ACCENT FOR TEXT / ICONS
    # -----------------------------------------------------

    raw_accent = select_accent(
        colors
    )

    # Keep the extracted wallpaper color unchanged when it
    # already meets the UI contrast requirement. Otherwise,
    # adjust only that color's HSV value/saturation while
    # preserving its hue.
    accent = adjust_contrast_preserve_hue(
        raw_accent,
        surface,
        minimum_ratio=4.5
    )

    # -----------------------------------------------------
    # SECONDARY ACCENT
    # -----------------------------------------------------

    raw_secondary = select_secondary(
        colors,
        raw_accent
    )

    accent_secondary = adjust_contrast_preserve_hue(
        raw_secondary,
        surface,
        minimum_ratio=4.5
    )

    # -----------------------------------------------------
    # TERTIARY ACCENT
    # -----------------------------------------------------

    # Select a third actual wallpaper color instead of rotating
    # the primary accent into an unrelated hue.
    raw_tertiary = select_secondary(
        colors,
        raw_accent,
        additional_avoid=(
            raw_secondary,
        )
    )

    accent_tertiary = adjust_contrast_preserve_hue(
        raw_tertiary,
        surface,
        minimum_ratio=4.5
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

        presentation_wallpaper = (
            create_presentation_frame(
                wallpaper
            )
        )

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

        "presentation_wallpaper": str(
            presentation_wallpaper
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
