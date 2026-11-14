#!/usr/bin/env bash

set -u

LOW_THRESHOLD=30
CRITICAL_THRESHOLD=15
DIM_PERCENT=35
POLL_INTERVAL=1

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/battery-monitor"
DIM_STATE="$STATE_DIR/brightness-before-dim"
WARNING_STATE="$STATE_DIR/warning-sent"
CRITICAL_STATE="$STATE_DIR/critical-sent"
PLUGGED_STATE="$STATE_DIR/charger-connected"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/low-battery-monitor-${UID}.lock"

mkdir -p "$STATE_DIR"

# Prevent multiple instances.
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

notify() {
    local urgency="$1"
    local title="$2"
    local message="$3"

    command -v notify-send >/dev/null 2>&1 || return 1

    notify-send --app-name="Battery Monitor" --urgency="$urgency" \
        "$title" "$message" >/dev/null 2>&1
}

# Check whether K4 already owns the notification service.
# This D-Bus call does NOT activate the notification service.
notification_server_running() {
    local owner

    owner="$(busctl --user call \
        org.freedesktop.DBus \
        /org/freedesktop/DBus \
        org.freedesktop.DBus \
        NameHasOwner s org.freedesktop.Notifications 2>/dev/null || true)"

    [[ "$owner" == "b true" ]]
}

find_battery() {
    local battery

    for battery in /sys/class/power_supply/BAT*; do
        [[ -r "$battery/capacity" && -r "$battery/status" ]] || continue
        printf '%s\n' "$battery"
        return 0
    done

    return 1
}

ac_is_online() {
    local supply

    for supply in /sys/class/power_supply/*; do
        [[ -r "$supply/online" ]] || continue
        [[ "$(<"$supply/online")" == "1" ]] && return 0
    done

    return 1
}

dim_screen() {
    local current maximum temporary_state

    current="$(brightnessctl -c backlight get 2>/dev/null)" || return 1
    maximum="$(brightnessctl -c backlight max 2>/dev/null)" || return 1

    [[ "$current" =~ ^[0-9]+$ && "$maximum" =~ ^[0-9]+$ ]] || return 1
    (( maximum > 0 )) || return 1

    # Save the exact original brightness.
    temporary_state="${DIM_STATE}.tmp.$$"
    printf '%s\n' "$current" > "$temporary_state" || return 1
    mv -f -- "$temporary_state" "$DIM_STATE" || return 1

    if (( current * 100 > maximum * DIM_PERCENT )); then
        if ! brightnessctl -q -c backlight set "${DIM_PERCENT}%"; then
            rm -f -- "$DIM_STATE"
            return 1
        fi
    fi

    return 0
}

restore_screen() {
    if [[ -f "$DIM_STATE" ]]; then
        local saved_brightness
        saved_brightness="$(<"$DIM_STATE")"

        if [[ "$saved_brightness" =~ ^[0-9]+$ ]]; then
            brightnessctl -q -c backlight set "$saved_brightness" || return 1
        fi

        rm -f -- "$DIM_STATE"
    fi

    rm -f -- "$WARNING_STATE" "$CRITICAL_STATE"
}

# Notify only when the charger changes from disconnected to connected.
# If K4 is closed, silently skip the notification.
track_charger_state() {
    local connected="$1"
    local status="$2"
    local capacity="$3"
    local previous=""

    if [[ -f "$PLUGGED_STATE" ]]; then
        previous="$(<"$PLUGGED_STATE")"
    fi

    if [[ "$previous" == "0" && "$connected" == "1" ]]; then

        local message

        case "$status" in
            Charging)
                message="You're plugged in and your battery is charging (${capacity}%)."
                ;;
            Full)
                message="Your charger is connected. Your battery is fully charged."
                ;;
            "Not charging")
                message="Your charger is connected, but your battery is not currently charging."
                ;;
            *)
                message="Your charger is connected. Battery level: ${capacity}%."
                ;;
        esac

        if notification_server_running; then
            notify low "Charger connected" "$message"
        fi
    fi

    # Always record the state, even when K4 is closed.
    # This prevents a delayed notification when K4 is opened later.
    printf '%s\n' "$connected" > "$PLUGGED_STATE"
}

while true; do
    battery="$(find_battery || true)"

    if [[ -n "$battery" ]]; then
        capacity="$(<"$battery/capacity")"
        status="$(<"$battery/status")"

        if [[ "$capacity" =~ ^[0-9]+$ ]]; then

            plugged_in=0

            if ac_is_online ||
               [[ "$status" == "Charging" ||
                  "$status" == "Full" ||
                  "$status" == "Not charging" ]]; then
                plugged_in=1
            fi

            # Handle charger connection independently of low battery alerts.
            track_charger_state "$plugged_in" "$status" "$capacity"

            if (( plugged_in == 1 )); then
                restore_screen

            elif [[ "$status" == "Discharging" ]] &&
                 (( capacity <= LOW_THRESHOLD )); then

                dim_message="Screen brightness is limited to ${DIM_PERCENT}%."

                if [[ ! -f "$DIM_STATE" ]] && ! dim_screen; then
                    dim_message="Screen brightness could not be adjusted."
                fi

                if (( capacity <= CRITICAL_THRESHOLD )); then
                    if [[ ! -f "$CRITICAL_STATE" ]]; then
                        if notify critical "Battery critically low" \
                            "Battery is at ${capacity}%. Connect the charger now."; then
                            : > "$CRITICAL_STATE"
                            : > "$WARNING_STATE"
                        fi
                    fi

                elif [[ ! -f "$WARNING_STATE" ]]; then
                    if notify normal "Battery low" \
                        "Battery is at ${capacity}%. ${dim_message}"; then
                        : > "$WARNING_STATE"
                    fi
                fi
            fi
        fi
    fi

    sleep "$POLL_INTERVAL"
done
