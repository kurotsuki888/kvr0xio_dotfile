#!/usr/bin/env bash

# Script para control de volumen con notificación OSD instantánea y barra animada

case "$1" in
    up)
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
        ;;
    down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
    mic-mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        ;;
esac

# Obtener estado actual del volumen
VOL_LINE=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)

if [[ "$VOL_LINE" =~ "[MUTED]" ]]; then
    notify-send -e -u low -a "OSD" \
        -h string:x-canonical-private-synchronous:osd \
        -h int:value:0 \
        -i audio-volume-muted \
        "Volumen" "Silenciado" \
        -t 1200
else
    VOL_VAL=$(echo "$VOL_LINE" | awk '{print int($2 * 100)}')
    
    if [ "$VOL_VAL" -ge 65 ]; then
        ICON="audio-volume-high"
    elif [ "$VOL_VAL" -ge 30 ]; then
        ICON="audio-volume-medium"
    elif [ "$VOL_VAL" -gt 0 ]; then
        ICON="audio-volume-low"
    else
        ICON="audio-volume-muted"
    fi

    notify-send -e -u low -a "OSD" \
        -h string:x-canonical-private-synchronous:osd \
        -h int:value:"$VOL_VAL" \
        -i "$ICON" \
        "Volumen" "${VOL_VAL}%" \
        -t 1200
fi
