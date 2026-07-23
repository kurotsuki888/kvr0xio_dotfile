#!/bin/bash

SOCK_EDP="/tmp/mpvpaper-eDP1.sock"
SOCK_HDMI="/tmp/mpvpaper-HDMI.sock"

# Flag de pausa manual — si existe, el demonio NO sobreescribe el estado
MANUAL_PAUSE_FLAG="/tmp/wp_manual_pause"

send_pause() {
    local sock="$1"
    local val="$2"
    if [ -S "$sock" ]; then
        echo "{ \"command\": [\"set_property\", \"pause\", $val] }" | socat -t 1 - "$sock" >/dev/null 2>&1 || true
    fi
}

check_and_toggle() {
    # Respetar pausa manual: si el flag existe, no tocar el estado
    [ -f "$MANUAL_PAUSE_FLAG" ] && return

    local monitors clients ws_edp ws_hdmi wins_edp wins_hdmi

    monitors=$(hyprctl monitors -j 2>/dev/null)
    [ -z "$monitors" ] && return

    clients=$(hyprctl clients -j 2>/dev/null)
    [ -z "$clients" ] && clients="[]"

    # Obtener workspace activo de cada monitor sin usar pipe (evita subshell)
    ws_edp=$(echo "$monitors"  | jq -r '.[] | select(.name == "eDP-1")   | .activeWorkspace.id' 2>/dev/null)
    ws_hdmi=$(echo "$monitors" | jq -r '.[] | select(.name == "HDMI-A-1") | .activeWorkspace.id' 2>/dev/null)

    # Contar ventanas visibles en cada workspace activo
    if [ -n "$ws_edp" ]; then
        wins_edp=$(echo "$clients" | jq "[.[] | select(.workspace.id == $ws_edp and .mapped == true)] | length" 2>/dev/null)
        wins_edp=${wins_edp:-0}
        if [ "$wins_edp" -gt 0 ]; then
            send_pause "$SOCK_EDP" "true"
        else
            send_pause "$SOCK_EDP" "false"
        fi
    fi

    if [ -n "$ws_hdmi" ]; then
        wins_hdmi=$(echo "$clients" | jq "[.[] | select(.workspace.id == $ws_hdmi and .mapped == true)] | length" 2>/dev/null)
        wins_hdmi=${wins_hdmi:-0}
        if [ "$wins_hdmi" -gt 0 ]; then
            send_pause "$SOCK_HDMI" "true"
        else
            send_pause "$SOCK_HDMI" "false"
        fi
    fi
}

if [ "${1:-}" == "check_only" ]; then
    check_and_toggle
    exit 0
fi

# Bucle principal
while true; do
    check_and_toggle
    sleep 1
done
