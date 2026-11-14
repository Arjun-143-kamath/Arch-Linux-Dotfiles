#!/usr/bin/env bash

set -euo pipefail

K4_DIR="$HOME/.config/quickshell/k4"

if [[ ! -r "$K4_DIR/shell.qml" ]]; then
    echo "K4 shell not found: $K4_DIR/shell.qml" >&2
    exit 1
fi

export QML_IMPORT_PATH="$K4_DIR/api${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"

# Keep Quickshell in the foreground so systemd can manage its lifetime.
exec /usr/bin/quickshell -p "$K4_DIR/shell.qml" --no-duplicate
