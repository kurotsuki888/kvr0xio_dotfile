#!/bin/bash
STATE_FILE="$HOME/.config/hypr/.current_wallpaper"
DEFAULT_WP="$HOME/Vídeos/Wallpapers/clean.mp4"

TARGET_WP="$DEFAULT_WP"
[ -f "$STATE_FILE" ] && TARGET_WP=$(cat "$STATE_FILE")

~/.config/hypr/scripts/set_wallpaper.sh "$TARGET_WP"
