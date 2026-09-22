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

# Only one video renderer should own the desktop at a time.
pkill -x mpvpaper 2>/dev/null || true

# =========================================================
# AWWW DAEMON
# =========================================================

# Walltheme owns the aww daemon. A running process is not enough;
# wait until the daemon is actually responding to commands.
ensure_awww_ready() {
    if ! pgrep -x awww-daemon >/dev/null 2>&1; then
        awww-daemon >/dev/null 2>&1 &
    fi

    for _ in {1..100}; do
        if awww query >/dev/null 2>&1; then
            return 0
        fi

        # If the daemon died while we were waiting, restart it.
        if ! pgrep -x awww-daemon >/dev/null 2>&1; then
            awww-daemon >/dev/null 2>&1 &
        fi

        sleep 0.1
    done

    echo "Walltheme: aww daemon did not become ready." >&2
    return 1
}

ensure_awww_ready || exit 1

case "$EXT" in

    mp4|webm|mkv)

        # =====================================================
        # PREPARE VIDEO PRESENTATION FRAME
        # =====================================================

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

        # =====================================================
        # WAIT FOR HYPRLAND MONITORS
        # =====================================================

        MONITORS=()

        for _ in {1..50}; do

            mapfile -t MONITORS < <(
                hyprctl monitors -j 2>/dev/null |
                    python -c '
import json
import sys

for monitor in json.load(sys.stdin):
    print(monitor["name"])
' 2>/dev/null || true
            )

            if [ "${#MONITORS[@]}" -gt 0 ]; then
                break
            fi

            sleep 0.2
        done

        if [ "${#MONITORS[@]}" -eq 0 ]; then
            echo "No Hyprland monitors became available."
            exit 1
        fi

        # Let the transition finish before mpvpaper starts
        # rendering from frame 0.
        sleep 0.6

        # =====================================================
        # START MPVPAPER
        # =====================================================

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

        # =====================================================
        # VERIFY MPVPAPER
        # =====================================================

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
