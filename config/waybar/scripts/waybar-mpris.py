#!/usr/bin/env python3
import json
import subprocess
import sys

def main():
    try:
        cmd = ["playerctl", "metadata", "--format", "{{status}}||{{playerName}}||{{title}}||{{artist}}"]
        output = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()
        if not output:
            print(json.dumps({"text": "", "class": "offline"}))
            return
            
        parts = output.split("||")
        if len(parts) < 4:
            print(json.dumps({"text": "", "class": "offline"}))
            return
            
        status, player, title, artist = parts[0], parts[1], parts[2].strip(), parts[3].strip()
        
        if not title:
            print(json.dumps({"text": "", "class": "offline"}))
            return

        status_icon = "󰐊" if status == "Playing" else ("󰏤" if status == "Paused" else "󰓛")
        
        player_lower = player.lower()
        if "spotify" in player_lower:
            player_icon = ""
        elif "firefox" in player_lower:
            player_icon = "󰈹"
        elif "mpv" in player_lower:
            player_icon = "🎵"
        elif "chromium" in player_lower or "chrome" in player_lower:
            player_icon = ""
        else:
            player_icon = "󰎈"

        display_text = f"{title} - {artist}" if artist else title
        max_len = 30
        if len(display_text) > max_len:
            display_text = display_text[:max_len - 1] + "…"

        text = f"{player_icon} {status_icon} {display_text}"
        tooltip = f"{player.capitalize()}: {title}" + (f" - {artist}" if artist else "")

        print(json.dumps({
            "text": text,
            "tooltip": tooltip,
            "class": status.lower()
        }, ensure_ascii=False))

    except Exception:
        print(json.dumps({"text": "", "class": "offline"}))

if __name__ == "__main__":
    main()
