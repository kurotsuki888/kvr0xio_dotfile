#!/bin/bash
set -euo pipefail

# Flag de pausa manual — el demonio wallpaper_control.sh lo respeta
MANUAL_PAUSE_FLAG="/tmp/wp_manual_pause"

ACTION="${1:-toggle}"

# Si la acción es "toggle", decidir según el estado actual del flag
if [ "$ACTION" == "toggle" ]; then
    if [ -f "$MANUAL_PAUSE_FLAG" ]; then
        ACTION="resume"
    else
        ACTION="pause"
    fi
fi

if [ "$ACTION" == "pause" ]; then
    PAUSE_VAL="true"
    MSG="Animación de wallpapers pausada (Modo Juego)"
    touch "$MANUAL_PAUSE_FLAG"
elif [ "$ACTION" == "resume" ]; then
    PAUSE_VAL="false"
    MSG="Animación de wallpapers reanudada"
    rm -f "$MANUAL_PAUSE_FLAG"
else
    echo "Uso: $0 [pause|resume|toggle]" >&2
    exit 1
fi

for sock in /tmp/mpvpaper-*.sock; do
    if [ -S "$sock" ]; then
        echo "{ \"command\": [\"set_property\", \"pause\", $PAUSE_VAL] }" | socat -t 1 - "$sock" >/dev/null 2>&1 || true
    fi
done

notify-send -t 2000 -u low "Wallpapers" "$MSG"
