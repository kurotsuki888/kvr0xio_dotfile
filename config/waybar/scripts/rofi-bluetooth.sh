#!/usr/bin/env bash
#
# rofi-bluetooth: menú desplegable para Bluetooth usando rofi + bluetoothctl
# Reemplaza a blueman-manager en waybar.

THEME="$HOME/.config/rofi/bluetooth-menu.rasi"
ROFI="rofi -dmenu -i -theme $THEME"

power_status() {
    bluetoothctl show | grep -q "Powered: yes" && echo "yes" || echo "no"
}

is_connected() {
    bluetoothctl info "$1" | grep -q "Connected: yes"
}

toggle_power() {
    if [[ $(power_status) == "yes" ]]; then
        bluetoothctl power off
        notify-send "Bluetooth" "Apagado" -i bluetooth-disabled
    else
        bluetoothctl power on
        sleep 1.5
        notify-send "Bluetooth" "Encendido" -i bluetooth-active
    fi
}

scan_devices() {
    notify-send "Bluetooth" "Buscando dispositivos (5s)..." -i bluetooth-active
    bluetoothctl --timeout 5 scan on >/dev/null 2>&1
}

toggle_connect() {
    local mac="$1"
    local name="$2"
    if is_connected "$mac"; then
        bluetoothctl disconnect "$mac" >/dev/null 2>&1
        notify-send "Bluetooth" "Desconectado: $name"
    else
        bluetoothctl connect "$mac" >/dev/null 2>&1
        if is_connected "$mac"; then
            notify-send "Bluetooth" "Conectado: $name"
        else
            notify-send "Bluetooth" "No se pudo conectar a $name" -u critical
        fi
    fi
}

main_menu() {
    local devices options status_line power

    power=$(power_status)

    if [[ "$power" == "yes" ]]; then
        status_line=" Bluetooth: Encendido"
    else
        status_line=" Bluetooth: Apagado"
    fi

    options="$status_line\n"

    if [[ "$power" == "yes" ]]; then
        devices=$(bluetoothctl devices | while read -r _ mac name; do
            if is_connected "$mac"; then
                echo "  $name"
            else
                echo "  $name"
            fi
        done)
        [[ -n "$devices" ]] && options+="$devices\n"
        options+=" Buscar dispositivos\n Apagar Bluetooth"
    else
        options+=" Encender Bluetooth"
    fi

    echo -e "$options" | $ROFI -p "Bluetooth"
}

while true; do
    chosen=$(main_menu)
    [[ -z "$chosen" ]] && exit 0

    case "$chosen" in
        *"Bluetooth: "*) continue ;;
        *"Buscar dispositivos"*) scan_devices ;;
        *"Encender Bluetooth"*|*"Apagar Bluetooth"*) toggle_power ;;
        *)
            # Extraer el nombre (sin el ícono inicial) y buscar su MAC
            name="${chosen:2}"
            mac=$(bluetoothctl devices | grep -F " $name" | awk '{print $2}' | head -n1)
            [[ -n "$mac" ]] && toggle_connect "$mac" "$name"
            ;;
    esac
done
