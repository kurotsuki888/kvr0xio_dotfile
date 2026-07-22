#!/bin/bash
set -euo pipefail

STATE_FILE="$HOME/.config/hypr/.current_wallpaper"
LOCK_FILE="/tmp/wp_switch.lock"
TARGET_WP="$1"

SOCK_EDP="/tmp/mpvpaper-eDP1.sock"
SOCK_HDMI="/tmp/mpvpaper-HDMI.sock"
SOCK_EDP_NEW="/tmp/mpvpaper-eDP1.new.sock"
SOCK_HDMI_NEW="/tmp/mpvpaper-HDMI.new.sock"

exec 200>"$LOCK_FILE"
flock -n 200 || { echo "Cambio de wallpaper ya en curso"; exit 1; }

[ -f "$TARGET_WP" ] || { echo "Archivo no existe: $TARGET_WP" >&2; exit 1; }

OPTS="no-audio --loop-file=inf --hwdec=auto --panscan=1.0 --image-display-duration=inf"

rm -f "$SOCK_EDP_NEW" "$SOCK_HDMI_NEW"

# 1. Lanza las instancias NUEVAS sin tocar las viejas (se solapan un instante)
mpvpaper -o "$OPTS --input-ipc-server=$SOCK_EDP_NEW" eDP-1 "$TARGET_WP" 200<&- &
disown
mpvpaper -o "$OPTS --input-ipc-server=$SOCK_HDMI_NEW" HDMI-A-1 "$TARGET_WP" 200<&- &
disown

# 2. Espera a que los sockets nuevos existan (proceso e IPC inicializados)
for i in $(seq 1 30); do
    [ -S "$SOCK_EDP_NEW" ] && [ -S "$SOCK_HDMI_NEW" ] && break
    sleep 0.1
done

# 3. Margen extra para asegurar que ya se pintó al menos un frame real
sleep 0.3

# 4. Recién ahora mata las instancias viejas — la pantalla nunca queda sin capa
for SOCK in "$SOCK_EDP" "$SOCK_HDMI"; do
    if [ -S "$SOCK" ]; then
        echo '{"command": ["quit"]}' | socat - "$SOCK" > /dev/null 2>&1 || true
    fi
done
pkill -f "$SOCK_EDP" 2>/dev/null || true
pkill -f "$SOCK_HDMI" 2>/dev/null || true

for i in $(seq 1 20); do
    pgrep -f "$SOCK_EDP" > /dev/null || break
    sleep 0.1
done

# 5. Renombra los sockets nuevos a los nombres "oficiales"
#    (mv no rompe el bind existente: el kernel identifica el socket por inodo,
#    no por path, así que el proceso sigue escuchando ahí sin reiniciarse)
rm -f "$SOCK_EDP" "$SOCK_HDMI"
mv "$SOCK_EDP_NEW" "$SOCK_EDP"
mv "$SOCK_HDMI_NEW" "$SOCK_HDMI"

echo "$TARGET_WP" > "$STATE_FILE"
