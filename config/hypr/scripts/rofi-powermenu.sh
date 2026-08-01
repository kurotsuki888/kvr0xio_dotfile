#!/usr/bin/env bash

THEME="$HOME/.config/rofi/powermenu.rasi"

LOCK="🔒 Bloquear pantalla"
LOGOUT="󰍃 Cerrar sesión"
REBOOT="󰜉 Reiniciar"
SHUTDOWN="󰐥 Apagar PC"

OPTIONS="$LOCK\n$LOGOUT\n$REBOOT\n$SHUTDOWN"

CHOSEN=$(echo -e "$OPTIONS" | rofi -dmenu -theme "$THEME" -p "Sistema")

case "$CHOSEN" in
    "$LOCK")
        i3lock || hyprlock || true
        ;;
    "$LOGOUT")
        i3-msg exit 2>/dev/null || hyprctl dispatch exit 2>/dev/null
        ;;
    "$REBOOT")
        systemctl reboot
        ;;
    "$SHUTDOWN")
        systemctl poweroff
        ;;
    *)
        exit 0
        ;;
esac
