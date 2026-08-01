#!/usr/bin/env bash
# Toggle SwayNC Notification Panel
if command -v swaync-client &>/dev/null; then
    swaync-client -t -sw
fi
