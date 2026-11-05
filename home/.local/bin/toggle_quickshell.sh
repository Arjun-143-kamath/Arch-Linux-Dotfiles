#!/bin/bash

if pgrep -x quickshell >/dev/null; then
    pkill -x quickshell
    pkill -f "portapapeles.py guardar" 2>/dev/null || true
else
    K4_DIR="$HOME/.config/quickshell/k4"
    if [ -x "$K4_DIR/arrancar" ]; then
        "$K4_DIR/arrancar" --no-duplicate -d &
    else
        quickshell -d &
    fi
fi
