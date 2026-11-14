#!/usr/bin/env bash

SERVICE="k4-notifications.service"

stop_helpers() {
    pkill -f "portapapeles.py guardar" 2>/dev/null || true
}

STATE="$(systemctl --user show "$SERVICE" --property=ActiveState --value 2>/dev/null || true)"

case "$STATE" in
    active|activating)
        systemctl --user stop "$SERVICE"
        stop_helpers
        ;;
    *)
        if pgrep -x quickshell >/dev/null 2>&1; then
            # Handle an older K4 instance started outside systemd.
            pkill -x quickshell
            stop_helpers
        else
            systemctl --user start "$SERVICE"
        fi
        ;;
esac
