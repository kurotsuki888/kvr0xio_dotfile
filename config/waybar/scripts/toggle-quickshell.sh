#!/usr/bin/env bash

# Toggle script for Quickshell popups in Waybar
TARGET="$1"
if [ -z "$TARGET" ]; then
    exit 1
fi

TARGET="${TARGET/#\~/$HOME}"
BASENAME=$(basename "$TARGET")

# Check if the quickshell binary process for this file is running
if pgrep -f "^quickshell -p .*${BASENAME}" > /dev/null 2>&1; then
    # If running, kill ONLY this quickshell popup
    pkill -f "^quickshell -p .*${BASENAME}"
else
    # Close any other open quickshell popups so only one menu is active at a time
    pkill -f "^quickshell -p" 2>/dev/null
    sleep 0.05
    # Launch the requested quickshell popup in background detached
    nohup quickshell -p "$TARGET" >/dev/null 2>&1 &
fi
