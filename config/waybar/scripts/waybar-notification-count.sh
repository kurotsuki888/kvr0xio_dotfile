#!/usr/bin/env bash
# Helper script to count Dunst notifications for Waybar badge

count=$(python3 -c "
import json, subprocess
try:
    res = subprocess.check_output(['dunstctl', 'history'], stderr=subprocess.DEVNULL).decode('utf-8', errors='ignore')
    data = json.loads(res)
    notifications = data.get('data', [[]])[0]
    print(len(notifications))
except Exception:
    print(0)
" 2>/dev/null)

if [ -z "$count" ] || [ "$count" -eq 0 ]; then
    echo '{"text": "󰂚", "tooltip": "Sin notificaciones", "class": "none"}'
else
    echo '{"text": "󰂚  '"$count"'", "tooltip": "'"$count"' Notificaciones", "class": "has-notifications"}'
fi
