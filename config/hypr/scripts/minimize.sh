#!/usr/bin/env bash

ACTION="${1:-toggle}"

case "$ACTION" in
    minimize)
        hyprctl eval 'hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", silent = true }))' >/dev/null 2>&1
        ;;
    toggle)
        hyprctl eval 'hl.dispatch(hl.dsp.workspace.toggle_special("minimized"))' >/dev/null 2>&1
        ;;
    restore)
        # Si la ventana activa está dentro del espacio especial, moverla al actual y ocultar el overlay
        active_ws=$(hyprctl activewindow -j | jq -r '.workspace.name // empty')
        if [[ "$active_ws" == "special:minimized" ]]; then
            hyprctl eval 'hl.dispatch(hl.dsp.window.move({ workspace = "+0" }))' >/dev/null 2>&1
            hyprctl eval 'hl.dispatch(hl.dsp.workspace.toggle_special("minimized"))' >/dev/null 2>&1
        else
            # Si estamos en el espacio normal, recuperar la última ventana minimizada
            addr=$(hyprctl clients -j | jq -r '[.[] | select(.workspace.name == "special:minimized")] | sort_by(.focusHistoryID) | .[0].address // empty')
            if [[ -n "$addr" && "$addr" != "null" ]]; then
                hyprctl eval "hl.dispatch(hl.dsp.window.move({ address = '$addr', workspace = '+0' }))" >/dev/null 2>&1
            else
                hyprctl eval 'hl.dispatch(hl.dsp.workspace.toggle_special("minimized"))' >/dev/null 2>&1
            fi
        fi
        ;;
esac
