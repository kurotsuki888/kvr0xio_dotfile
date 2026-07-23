#!/bin/bash

STATE_FILE="$HOME/.config/hypr/.current_wallpaper"
LOCK_FILE="/tmp/wp_switch.lock"
TARGET_WP="$1"

SOCK_EDP="/tmp/mpvpaper-eDP1.sock"
SOCK_HDMI="/tmp/mpvpaper-HDMI.sock"

exec 200>"$LOCK_FILE"
flock -n 200 || { echo "Cambio de wallpaper ya en curso"; exit 1; }

[ -f "$TARGET_WP" ] || { echo "Archivo no existe: $TARGET_WP" >&2; exit 1; }

OPTS="no-audio --loop-file=inf --hwdec=auto-safe --panscan=1.0 --image-display-duration=inf"

# 0. Liberar VRAM y sockets previos
killall mpvpaper 2>/dev/null || true
rm -f "$SOCK_EDP" "$SOCK_HDMI"
sleep 0.3

# 1. Cerrar el FD del lock ANTES de lanzar hijos (evita que hereden el flock)
exec 200>&-

# 2. Lanza mpvpaper con nohup y disown
nohup mpvpaper -o "$OPTS --input-ipc-server=$SOCK_EDP" eDP-1 "$TARGET_WP" >/dev/null 2>&1 &
disown

nohup mpvpaper -o "$OPTS --input-ipc-server=$SOCK_HDMI" HDMI-A-1 "$TARGET_WP" >/dev/null 2>&1 &
disown

# 3. Espera a que los sockets existan (cada monitor de forma independiente)
for i in $(seq 1 30); do
    [ -S "$SOCK_EDP" ] && break
    sleep 0.1
done
for i in $(seq 1 30); do
    [ -S "$SOCK_HDMI" ] && break
    sleep 0.1
done

echo "$TARGET_WP" > "$STATE_FILE"

# 4. Dar margen a libmpv para inicializar IPC antes de actualizar estado en segundo plano
(sleep 1.5 && ~/.config/hypr/scripts/wallpaper_control.sh check_only >/dev/null 2>&1) &
