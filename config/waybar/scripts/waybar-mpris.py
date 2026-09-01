#!/usr/bin/env python3
import json
import subprocess
import os
import sys
import time

BARS = [" ", " ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

def get_player_info():
    try:
        cmd = ["playerctl", "metadata", "--format", "{{status}}||{{playerName}}||{{title}}||{{artist}}"]
        output = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()
        if not output:
            return None
        parts = output.split("||")
        if len(parts) < 4:
            return None
        status, player, title, artist = parts[0], parts[1], parts[2].strip(), parts[3].strip()
        if not title:
            return None
        return status, player, title, artist
    except Exception:
        return None

def main():
    cava_config = """
[general]
bars = 4
framerate = 25

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 8
"""
    tmp_config = "/tmp/waybar_cava_config"
    with open(tmp_config, "w") as f:
        f.write(cava_config)

    cava_proc = None
    last_check_time = 0
    info = None

    try:
        while True:
            now = time.time()
            if now - last_check_time > 1.0:
                info = get_player_info()
                last_check_time = now

            if not info:
                print(json.dumps({"text": "", "class": "offline"}), flush=True)
                if cava_proc:
                    cava_proc.terminate()
                    cava_proc = None
                time.sleep(2)
                continue

            status, player, title, artist = info
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
            max_len = 25
            if len(display_text) > max_len:
                display_text = display_text[:max_len - 1] + "…"

            tooltip = f"{player.capitalize()}: {title}" + (f" - {artist}" if artist else "")

            if status != "Playing":
                if cava_proc:
                    cava_proc.terminate()
                    cava_proc = None
                text = f"{player_icon} 󰏤 {display_text}"
                print(json.dumps({
                    "text": text,
                    "tooltip": tooltip,
                    "class": "paused"
                }, ensure_ascii=False), flush=True)
                time.sleep(1)
                continue

            # Si está Playing, asegurarse de que cava está corriendo
            if cava_proc is None or cava_proc.poll() is not None:
                try:
                    cava_proc = subprocess.Popen(
                        ["cava", "-p", tmp_config],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.DEVNULL,
                        text=True,
                        bufsize=1
                    )
                except Exception:
                    cava_proc = None

            if cava_proc and cava_proc.stdout:
                line = cava_proc.stdout.readline()
                if not line:
                    time.sleep(0.05)
                    continue
                values = [v for v in line.strip().split(';') if v.isdigit()]
                if values:
                    bars_viz = "".join(BARS[min(int(v), len(BARS)-1)] for v in values)
                else:
                    bars_viz = "    "
                
                text = f"{player_icon} {bars_viz} {display_text}"
                print(json.dumps({
                    "text": text,
                    "tooltip": tooltip,
                    "class": "playing"
                }, ensure_ascii=False), flush=True)
            else:
                text = f"{player_icon} 󰐊 {display_text}"
                print(json.dumps({
                    "text": text,
                    "tooltip": tooltip,
                    "class": "playing"
                }, ensure_ascii=False), flush=True)
                time.sleep(0.2)

    except KeyboardInterrupt:
        pass
    finally:
        if cava_proc:
            cava_proc.terminate()

if __name__ == "__main__":
    main()

