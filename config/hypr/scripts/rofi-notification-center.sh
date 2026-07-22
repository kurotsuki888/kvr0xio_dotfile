#!/usr/bin/env bash

THEME="$HOME/.config/rofi/notification-center.rasi"

is_paused=$(dunstctl is-paused 2>/dev/null || echo "false")
if [[ "$is_paused" == "true" ]]; then
    dnd_status="󰂛 Desactivar No Molestar"
else
    dnd_status="󰂚 Activar No Molestar"
fi

CLEAR_HIST="󰎟 Limpiar Historial"

# Fetch notification history via Python
NOTIFS=$(python3 -c "
import json, subprocess, re
try:
    res = subprocess.check_output(['dunstctl', 'history'])
    data = json.loads(res)
    notifications = data.get('data', [[]])[0]
    out = []
    for n in notifications[:10]:
        summary = n.get('summary', {}).get('data', 'Notificación').strip()
        body = n.get('body', {}).get('data', '').strip()
        body_clean = re.sub('<[^<]+?>', '', body)
        if body_clean:
            out.append(f'󰂞 {summary} - {body_clean}')
        else:
            out.append(f'󰂞 {summary}')
    print('\n'.join(out))
except Exception:
    pass
")

if [[ -z "$NOTIFS" ]]; then
    MENU="$dnd_status\n$CLEAR_HIST\nSin notificaciones recientes"
else
    MENU="$dnd_status\n$CLEAR_HIST\n$NOTIFS"
fi

CHOSEN=$(echo -e "$MENU" | rofi -dmenu -theme "$THEME" -p "Notificaciones")

case "$CHOSEN" in
    *"No Molestar"*)
        dunstctl set-paused toggle
        ;;
    *"Limpiar Historial"*)
        dunstctl history-clear
        ;;
    *)
        exit 0
        ;;
esac
