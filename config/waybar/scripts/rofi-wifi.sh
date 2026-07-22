#!/usr/bin/env bash
#
# rofi-wifi: menú desplegable para WiFi usando rofi + nmcli
# Reemplaza al nmtui flotante en waybar.

THEME="$HOME/.config/rofi/wifi-menu.rasi"
ROFI="rofi -dmenu -i -theme $THEME"

current_ssid() {
    nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2
}

wifi_radio_status() {
    nmcli radio wifi
}

toggle_radio() {
    if [[ $(wifi_radio_status) == "enabled" ]]; then
        nmcli radio wifi off
        notify-send "WiFi" "Apagado" -i network-wireless-disabled
    else
        nmcli radio wifi on
        sleep 1
        notify-send "WiFi" "Encendido" -i network-wireless
    fi
}

connect_to() {
    local ssid="$1"
    local active
    active=$(current_ssid)

    if [[ "$ssid" == "$active" ]]; then
        nmcli connection down "$ssid" >/dev/null 2>&1
        notify-send "WiFi" "Desconectado de $ssid"
        return
    fi

    # ¿ya existe un perfil guardado para esta red?
    if nmcli -t -f NAME connection show | grep -qxF "$ssid"; then
        if nmcli connection up "$ssid" >/dev/null 2>&1; then
            notify-send "WiFi" "Conectado a $ssid"
        else
            notify-send "WiFi" "No se pudo conectar a $ssid" -u critical
        fi
    else
        local pass
        pass=$(rofi -dmenu -password -theme "$THEME" -p "Contraseña de $ssid")
        [[ -z "$pass" ]] && return
        if nmcli dev wifi connect "$ssid" password "$pass" >/dev/null 2>&1; then
            notify-send "WiFi" "Conectado a $ssid"
        else
            notify-send "WiFi" "Contraseña incorrecta o fallo de conexión" -u critical
        fi
    fi
}

main_menu() {
    local radio active networks options

    radio=$(wifi_radio_status)

    if [[ "$radio" != "enabled" ]]; then
        echo -e " WiFi: Apagado\n Encender WiFi" | $ROFI -p "WiFi"
        return
    fi

    active=$(current_ssid)
    nmcli dev wifi rescan >/dev/null 2>&1
    sleep 1

    networks=$(nmcli -t -f ssid,signal,security dev wifi list | awk -F: '!seen[$1]++' | while IFS=: read -r ssid signal sec; do
        [[ -z "$ssid" ]] && continue
        icon="󰤨"
        [[ "$signal" -lt 70 ]] && icon="󰤥"
        [[ "$signal" -lt 40 ]] && icon="󰤢"
        [[ "$signal" -lt 20 ]] && icon="󰤟"
        lock=""
        [[ -n "$sec" ]] && lock=" 󰌾"
        if [[ "$ssid" == "$active" ]]; then
            echo "$icon $ssid$lock (conectado)"
        else
            echo "$icon $ssid$lock"
        fi
    done)

    options="$networks\n Apagar WiFi"
    echo -e "$options" | $ROFI -p "WiFi"
}

chosen=$(main_menu)
[[ -z "$chosen" ]] && exit 0

case "$chosen" in
    *"WiFi: "*) exit 0 ;;
    *"Encender WiFi"*|*"Apagar WiFi"*) toggle_radio ;;
    *)
        # Limpia ícono, candado y sufijo "(conectado)" para quedarnos con el SSID
        ssid=$(echo "$chosen" | sed -E 's/^. //; s/ 󰌾//; s/ \(conectado\)$//')
        connect_to "$ssid"
        ;;
esac
