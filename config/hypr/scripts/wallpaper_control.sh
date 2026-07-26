#!/bin/bash

SOCK_EDP="/tmp/mpvpaper-eDP1.sock"
SOCK_HDMI="/tmp/mpvpaper-HDMI.sock"

# Flag de pausa manual — si existe, el demonio NO sobreescribe el estado
MANUAL_PAUSE_FLAG="/tmp/wp_manual_pause"

# Estado anterior por monitor (evita enviar comandos repetidos innecesariamente)
PREV_EDP=""
PREV_HDMI=""

send_pause() {
    local sock="$1"
    local val="$2"
    if [ -S "$sock" ]; then
        echo "{ \"command\": [\"set_property\", \"pause\", $val] }" | socat -t 1 - UNIX-CONNECT:"$sock" > /dev/null 2>&1 || true
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

    ws_edp=$(echo "$monitors"  | jq -r '.[] | select(.name == "eDP-1")   | .activeWorkspace.id' 2>/dev/null)
    ws_hdmi=$(echo "$monitors" | jq -r '.[] | select(.name == "HDMI-A-1") | .activeWorkspace.id' 2>/dev/null)

    # --- Monitor eDP-1 ---
    if [ -n "$ws_edp" ]; then
        wins_edp=$(echo "$clients" | jq "[.[] | select(.workspace.id == $ws_edp and .mapped == true)] | length" 2>/dev/null)
        wins_edp=${wins_edp:-0}
        local new_state_edp
        [ "$wins_edp" -gt 0 ] && new_state_edp="throttle" || new_state_edp="play"

        # Solo enviar si cambió el estado (evita socat innecesario cada segundo)
        if [ "$new_state_edp" != "$PREV_EDP" ]; then
            if [ "$new_state_edp" = "throttle" ]; then
                throttle_monitor "$SOCK_EDP"
            else
                resume_monitor "$SOCK_EDP"
            fi
            PREV_EDP="$new_state_edp"
        fi
    fi

    # --- Monitor HDMI-A-1 ---
    if [ -n "$ws_hdmi" ]; then
        wins_hdmi=$(echo "$clients" | jq "[.[] | select(.workspace.id == $ws_hdmi and .mapped == true)] | length" 2>/dev/null)
        wins_hdmi=${wins_hdmi:-0}
        local new_state_hdmi
        [ "$wins_hdmi" -gt 0 ] && new_state_hdmi="throttle" || new_state_hdmi="play"

        if [ "$new_state_hdmi" != "$PREV_HDMI" ]; then
            if [ "$new_state_hdmi" = "throttle" ]; then
                throttle_monitor "$SOCK_HDMI"
            else
                resume_monitor "$SOCK_HDMI"
            fi
            PREV_HDMI="$new_state_hdmi"
        fi
    fi
}

if [ "${1:-}" == "check_only" ]; then
    check_and_toggle
    exit 0
fi

# Bucle principal — cada 2s es suficiente, reduce CPU del script
while true; do
    check_and_toggle
    sleep 2
done
