#!/bin/bash

STATE_FILE="/tmp/waybar_clock_state"

if [ ! -f "$STATE_FILE" ]; then
  echo "time" >"$STATE_FILE"
fi

STATE=$(cat "$STATE_FILE")

if [ "$1" = "toggle" ]; then
  if [ "$STATE" = "time" ]; then
    echo "date" >"$STATE_FILE"
  else
    echo "time" >"$STATE_FILE"
  fi
  exit 0
fi

if [ "$STATE" = "time" ]; then
  date "+󰥔 %H:%M"
else
  date "+󰃭 %A, %d %B %Y"
fi
