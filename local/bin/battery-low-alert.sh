#!/usr/bin/env bash

# Configuración de entorno gráfico si se ejecuta desde systemd
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"

# Detectar Wayland socket
if [ -z "$WAYLAND_DISPLAY" ]; then
    for w in "$XDG_RUNTIME_DIR"/wayland-*; do
        if [ -S "$w" ]; then
            export WAYLAND_DISPLAY="$(basename "$w")"
            break
        fi
    done
fi

# Detectar X11 Display
if [ -z "$DISPLAY" ]; then
    for x in /tmp/.X11-unix/X*; do
        if [ -S "$x" ]; then
            num="${x##*/X}"
            export DISPLAY=":$num"
            break
        fi
    done
    [ -z "$DISPLAY" ] && export DISPLAY=":0"
fi

# Parámetros de alerta
THRESHOLD=10
CHECK_INTERVAL=10 # Revisar cada 10 segundos para mayor inmediatez
REMIND_INTERVAL=120
LAST_ALERT=0

find_battery() {
    for b in /sys/class/power_supply/BAT*; do
        if [ -d "$b" ]; then
            echo "$b"
            return
        fi
    done
}

find_ac_adapter() {
    for ac in /sys/class/power_supply/A{C,DP}*; do
        if [ -f "$ac/online" ]; then
            echo "$ac/online"
            return
        fi
    done
}

BAT_PATH=$(find_battery)
AC_ONLINE_PATH=$(find_ac_adapter)

if [ -z "$BAT_PATH" ]; then
    echo "No se encontró ninguna batería en el sistema." >&2
    exit 1
fi

while true; do
    if [ -f "$BAT_PATH/capacity" ]; then
        CAPACITY=$(cat "$BAT_PATH/capacity" 2>/dev/null || echo 100)
        STATUS=$(cat "$BAT_PATH/status" 2>/dev/null || echo "Unknown")
        
        # Verificar si está conectado a la corriente
        IS_CHARGING=false
        if [ "$STATUS" = "Charging" ] || [ "$STATUS" = "Full" ]; then
            IS_CHARGING=true
        elif [ -n "$AC_ONLINE_PATH" ] && [ -f "$AC_ONLINE_PATH" ]; then
            if [ "$(cat "$AC_ONLINE_PATH" 2>/dev/null)" = "1" ]; then
                IS_CHARGING=true
            fi
        fi

        CURRENT_TIME=$(date +%s)

        # Condición: <= 10% y NO se está cargando
        if [ "$CAPACITY" -le "$THRESHOLD" ] && [ "$IS_CHARGING" = false ]; then
            if [ $((CURRENT_TIME - LAST_ALERT)) -ge "$REMIND_INTERVAL" ]; then
                LAST_ALERT=$CURRENT_TIME

                # Sonido de alerta en segundo plano
                if command -v canberra-gtk-play >/dev/null 2>&1; then
                    canberra-gtk-play -i dialog-warning &
                elif [ -f /usr/share/sounds/freedesktop/stereo/dialog-warning.oga ] && command -v paplay >/dev/null 2>&1; then
                    paplay /usr/share/sounds/freedesktop/stereo/dialog-warning.oga &
                fi

                # Notificación de escritorio
                notify-send -u critical -i battery-caution "⚠️ BATERÍA CRÍTICA (${CAPACITY}%)" "No se detecta cargador conectado. Conéctalo inmediatamente." 2>/dev/null &

                # Cuadro emergente en el centro de la pantalla
                zenity --warning \
                    --title="⚠️ BATERÍA BAJA" \
                    --text="<span size='xx-large' weight='bold' foreground='red'>¡BATERÍA CRÍTICA: ${CAPACITY}%!</span>\n\n<b>El equipo no se está cargando.</b>\nPor favor conecta el cargador inmediatamente para evitar que se apague." \
                    --width=450 \
                    --height=200 \
                    --timeout=120 &
            fi
        elif [ "$IS_CHARGING" = true ] || [ "$CAPACITY" -gt "$THRESHOLD" ]; then
            # Reiniciar al conectar el cargador
            LAST_ALERT=0
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
