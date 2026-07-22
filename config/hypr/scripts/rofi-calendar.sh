#!/usr/bin/env bash
#
# rofi-calendar: calendario flotante navegable con rofi + cal
# Uso: se auto-invoca con un offset de meses (0 = mes actual)

THEME="$HOME/.config/rofi/calendar-menu.rasi"
ROFI=(rofi -dmenu -theme "$THEME" -theme-str 'listview { lines: 11; }')

offset="${1:-0}"

target_year=$(date -d "$offset month" +%Y)
target_month=$(date -d "$offset month" +%m)
month_label=$(date -d "$offset month" +"%B %Y")

cal_output=$(cal "$target_month" "$target_year" 2>/dev/null)

# Botones de navegación siempre primero, para que nunca queden fuera de vista
menu="◀ Mes anterior
Mes siguiente ▶"

[[ "$offset" != "0" ]] && menu="$menu
 Hoy"

menu="$menu

$cal_output"

chosen=$(echo -e "$menu" | "${ROFI[@]}" -p "$month_label")

case "$chosen" in
    "◀ Mes anterior") exec "$0" $((offset - 1)) ;;
    "Mes siguiente ▶") exec "$0" $((offset + 1)) ;;
    *" Hoy"*) exec "$0" 0 ;;
    *) exit 0 ;;
esac
