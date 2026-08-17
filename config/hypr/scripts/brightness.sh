#!/usr/bin/env bash

# Script para control de brillo con notificación OSD instantánea y barra animada

case "$1" in
    up)
        brightnessctl set 5%+
        ;;
    down)
        brightnessctl set 5%-
        ;;
esac

# Obtener porcentaje actual de brillo
BRIGHT_VAL=$(brightnessctl -m | cut -d, -f4 | tr -d '%')

if [ -z "$BRIGHT_VAL" ]; then
    exit 0
fi

if [ "$BRIGHT_VAL" -ge 65 ]; then
    ICON="display-brightness-high"
elif [ "$BRIGHT_VAL" -ge 30 ]; then
    ICON="display-brightness-medium"
else
    ICON="display-brightness-low"
fi

notify-send -e -u low -a "OSD" \
    -h string:x-canonical-private-synchronous:osd \
    -h int:value:"$BRIGHT_VAL" \
    -i "$ICON" \
    "Brillo" "${BRIGHT_VAL}%" \
    -t 1200
