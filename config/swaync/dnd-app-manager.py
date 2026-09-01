#!/usr/bin/env python3
import json
import os
import subprocess
import sys

CONFIG_FILE = os.path.expanduser("~/.config/swaync/config.json")
ROFI_THEME = os.path.expanduser("~/.config/rofi/notification-center.rasi")

def load_config():
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def save_config(data):
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    subprocess.run(["swaync-client", "--reload-config"])

def get_installed_apps():
    # Common apps list with their regex patterns
    known_apps = [
        {"name": "WhatSie / WhatsApp", "key": "whatsie-app", "app-name": "(?i).*whatsie.*|.*whatsapp.*"},
        {"name": "Claude Desktop", "key": "claude", "app-name": "(?i).*claude.*"},
        {"name": "Antigravity", "key": "antigravity", "app-name": "(?i).*antigravity.*"},
        {"name": "Firefox / Mozilla", "key": "firefox", "app-name": "(?i).*firefox.*|.*mozilla.*"},
        {"name": "Discord", "key": "discord", "app-name": "(?i).*discord.*|.*vesktop.*"},
        {"name": "Slack", "key": "slack", "app-name": "(?i).*slack.*"},
        {"name": "Spotify", "key": "spotify", "app-name": "(?i).*spotify.*"},
        {"name": "Telegram", "key": "telegram", "app-name": "(?i).*telegram.*"},
        {"name": "Thunderbird / Mail", "key": "mail", "app-name": "(?i).*thunderbird.*|.*mail.*"},
        {"name": "Dispositivos USB/Bluetooth", "key": "devices", "app-name": "(?i).*device.*|.*udisk.*|.*bluetooth.*|.*usb.*"}
    ]
    return known_apps

def main():
    config = load_config()
    visibility = config.get("notification-visibility", {})
    apps = get_installed_apps()

    options = []
    for app in apps:
        k = app["key"]
        rule = visibility.get(k, {})
        # muted or ignored means DND for that app
        state = rule.get("state", "enabled")
        if state in ("muted", "ignored"):
            status_icon = "󰂛 [SILENCIADA / NO MOLESTAR]"
        else:
            status_icon = "󰂚 [PERMITIDA / ACTIVA]"
        options.append(f"{status_icon} {app['name']}")

    rofi_cmd = ["rofi", "-dmenu", "-i", "-p", "Silenciar App"]
    if os.path.exists(ROFI_THEME):
        rofi_cmd.extend(["-theme", ROFI_THEME])

    res = subprocess.run(rofi_cmd, input="\n".join(options), text=True, capture_output=True)
    selected = res.stdout.strip()
    if not selected:
        return

    # Find matching app
    for app in apps:
        if app["name"] in selected:
            k = app["key"]
            curr_state = visibility.get(k, {}).get("state", "enabled")
            new_state = "muted" if curr_state == "enabled" else "enabled"
            
            visibility[k] = {
                "state": new_state,
                "app-name": app["app-name"]
            }
            config["notification-visibility"] = visibility
            save_config(config)
            
            estado_txt = "Silenciada (No molestar)" if new_state == "muted" else "Permitida (Notificaciones activas)"
            subprocess.run(["notify-send", "Control de Notificaciones", f"{app['name']}: {estado_txt}"])
            break

if __name__ == "__main__":
    main()
