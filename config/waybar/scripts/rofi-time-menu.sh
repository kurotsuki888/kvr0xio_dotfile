#!/usr/bin/env bash
#
# rofi-time-menu: menú desplegable de reloj con rofi
# Muestra hora con segundos + cronómetro + temporizador + alarma
# Requiere: rofi, systemd (systemd-run), notify-send, kitty (para el cronómetro)

THEME="$HOME/.config/rofi/calendar-menu.rasi"
ROFI="rofi -dmenu -theme $THEME"

set_timer() {
    mins=$(echo "" | $ROFI -p "Temporizador: minutos (ej: 1.5)")
    [[ -z "$mins" ]] && return

    secs=$(awk "BEGIN{v=$mins*60; printf \"%d\", (v==int(v))?v:int(v)+1}" 2>/dev/null)
    if [[ -z "$secs" || "$secs" -le 0 ]]; then
        notify-send "Temporizador" "Valor inválido" -u critical
        return
    fi

    unit="temporizador-$(date +%s)"
    systemd-run --user --unit="$unit" --on-active="${secs}s" \
        /usr/bin/notify-send -u critical "Temporizador" "¡Tiempo cumplido! ($mins min)" >/dev/null 2>&1

    notify-send "Temporizador" "Iniciado: $mins min"
}

set_alarm() {
    hora=$(echo "" | $ROFI -p "Alarma: hora (HH:MM, 24h)")
    [[ -z "$hora" ]] && return

    if ! [[ "$hora" =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        notify-send "Alarma" "Formato inválido, usa HH:MM" -u critical
        return
    fi

    target=$(date -d "$hora" +%s)
    now=$(date +%s)
    [[ "$target" -le "$now" ]] && target=$(date -d "tomorrow $hora" +%s)
    secs=$((target - now))

    unit="alarma-$(date +%s)"
    systemd-run --user --unit="$unit" --on-active="${secs}s" \
        /usr/bin/notify-send -u critical "Alarma" "¡Son las $hora!" >/dev/null 2>&1

    notify-send "Alarma" "Programada para las $hora"
}

start_stopwatch() {
    kitty --class rofi-stopwatch --title "Cronómetro" -e bash -c '
        start=$(date +%s)
        trap "exit 0" INT TERM
        while true; do
            elapsed=$(( $(date +%s) - start ))
            printf "\rCronómetro:  %02d:%02d:%02d   (Ctrl+C para detener) " \
                $((elapsed/3600)) $(((elapsed/60)%60)) $((elapsed%60))
            sleep 1
        done
    ' &
    disown
}

cancel_pending() {
    mapfile -t units < <(systemctl --user list-timers --no-legend 2>/dev/null \
        | awk '{print $(NF-1)}' | grep -E '^(temporizador|alarma)-.*\.timer$')

    if [[ ${#units[@]} -eq 0 ]]; then
        notify-send "Reloj" "No hay temporizadores ni alarmas activos"
        return
    fi

    chosen=$(printf "%s\n" "${units[@]}" | $ROFI -p "Cancelar")
    if [[ -n "$chosen" ]]; then
        systemctl --user stop "$chosen" 2>/dev/null
        notify-send "Reloj" "Cancelado: $chosen"
    fi
}

while true; do
    now=$(date +"%H:%M:%S")
    menu=" $now
 Cronómetro
 Temporizador
 Alarma
 Cancelar temporizador/alarma"

    chosen=$(echo -e "$menu" | $ROFI -p "Reloj")
    [[ -z "$chosen" ]] && exit 0

    case "$chosen" in
        *"Cronómetro"*) start_stopwatch; exit 0 ;;
        *"Temporizador"*) set_timer ;;
        *"Alarma"*) set_alarm ;;
        *"Cancelar"*) cancel_pending ;;
        *) continue ;;
    esac
done
