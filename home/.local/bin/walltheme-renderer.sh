#!/bin/bash

set -euo pipefail

WALL="${1:-}"

if [ -z "$WALL" ] || [ ! -f "$WALL" ]; then
    echo "Wallpaper not found:"
    echo "  $WALL"
    exit 1
fi

EXT="${WALL##*.}"
EXT="${EXT,,}"

# Only one renderer should own the desktop at a time.
pkill -x mpvpaper 2>/dev/null || true

case "$EXT" in

    mp4|webm|mkv)

        # Ask Walltheme for the cached first frame.
        # On a cache miss, Walltheme generates and stores
        # both first.png and middle.png.
        FIRST_FRAME="$(
            python - "$WALL" <<'PY'
import importlib.util
from pathlib import Path
import sys

wallpaper = Path(sys.argv[1]).resolve()
module_path = (
    Path.home()
    / ".config"
    / "walltheme"
    / "walltheme.py"
)

spec = importlib.util.spec_from_file_location(
    "walltheme",
    module_path,
)

if spec is None or spec.loader is None:
    raise SystemExit(
        "Could not load Walltheme."
    )

module = importlib.util.module_from_spec(
    spec
)

spec.loader.exec_module(
    module
)

first, _middle = module.prepare_video_frames(
    wallpaper
)

print(first)
PY
        )"

        if [ -z "$FIRST_FRAME" ] || [ ! -f "$FIRST_FRAME" ]; then
            echo "Failed to prepare video frames:"
            echo "  $WALL"
            exit 1
        fi

        # Fade into the exact first frame of the video.
        awww img "$FIRST_FRAME" \
            --transition-type fade \
            --transition-fps 60 \
            --transition-duration 0.6

        mapfile -t MONITORS < <(
            hyprctl monitors -j |
                python -c '
import json
import sys

for monitor in json.load(sys.stdin):
    print(monitor["name"])
'
        )

        if [ "${#MONITORS[@]}" -eq 0 ]; then
            echo "No Hyprland monitors found."
            exit 1
        fi

        # Let the transition finish before mpvpaper starts
        # rendering from frame 0.
        sleep 0.6

        PIDS=()

        for monitor in "${MONITORS[@]}"; do
            mpvpaper \
                -o "no-audio --loop-file=inf --no-osc --osd-level=0 --really-quiet" \
                "$monitor" \
                "$WALL" \
                >/dev/null 2>&1 &

            PIDS+=("$!")
        done

        sleep 0.2

        for pid in "${PIDS[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                for started in "${PIDS[@]}"; do
                    kill "$started" 2>/dev/null || true
                done

                echo "mpvpaper failed to start for:"
                echo "  $WALL"
                exit 1
            fi
        done

        ;;

    *)
        awww img "$WALL" \
            --transition-type fade \
            --transition-fps 60 \
            --transition-duration 0.6
        ;;

esac
