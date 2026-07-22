#!/bin/bash

HYPR_SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

check_and_toggle() {
    # Extraemos el JSON de monitores
    MONITORS=$(hyprctl monitors -j)
    
    # Iteramos sobre cada monitor conectado
    echo "$MONITORS" | jq -c '.[]' | while read -r monitor; do
        MON_NAME=$(echo "$monitor" | jq -r '.name')
        WS_ID=$(echo "$monitor" | jq -r '.activeWorkspace.id')
        
        # Consultamos las ventanas exclusivas del workspace activo de ESTE monitor
        WINDOWS=$(hyprctl workspaces -j | jq -r ".[] | select(.id==$WS_ID) | .windows" 2>/dev/null)
        WINDOWS=${WINDOWS:-0}
        
        # Mapeamos el socket correspondiente
        if [ "$MON_NAME" == "eDP-1" ]; then
            SOCK="/tmp/mpvpaper-eDP1.sock"
        elif [ "$MON_NAME" == "HDMI-A-1" ]; then
            SOCK="/tmp/mpvpaper-HDMI.sock"
        else
            continue
        fi
        
        # Evaluamos y enviamos la instrucción por IPC
        if [ "$WINDOWS" -gt 0 ]; then
            echo '{ "command": ["set_property", "pause", true] }' | socat - "$SOCK" > /dev/null 2>&1
        else
            echo '{ "command": ["set_property", "pause", false] }' | socat - "$SOCK" > /dev/null 2>&1
        fi
    done
}

# Ejecución inicial
check_and_toggle

# Bucle de eventos en tiempo real
socat -U - UNIX-CONNECT:"$HYPR_SOCKET" | while read -r line; do
    case "$line" in
        openwindow*|closewindow*|workspace*|movewindow*)
            check_and_toggle
            ;;
    esac
done
