#!/usr/bin/env python3
import json
import subprocess
import sys
import os

def main():
    # 1. Obtener monitor activo
    try:
        monitors_raw = subprocess.check_output(["hyprctl", "monitors", "-j"], stderr=subprocess.DEVNULL)
        monitors = json.loads(monitors_raw)
        active_mon_id = next((m["id"] for m in monitors if m.get("focused")), 0)
    except Exception:
        active_mon_id = 0

    # 2. Obtener ventanas
    try:
        clients_raw = subprocess.check_output(["hyprctl", "clients", "-j"], stderr=subprocess.DEVNULL)
        clients = json.loads(clients_raw)
    except Exception:
        sys.exit(0)

    # 3. Filtrar solo ventanas de la pantalla/monitor actual (incluye minimizadas de este monitor)
    windows = [c for c in clients if c.get("monitor") == active_mon_id]
    if not windows:
        sys.exit(0)

    # Ordenar por historial de foco
    windows.sort(key=lambda x: x.get("focusHistoryID", 999))

    # Mapeo de nombres de iconos comunes
    def get_icon(c):
        cls = (c.get("initialClass") or c.get("class") or "").lower()
        if "chromium" in cls:
            return "chromium"
        if "spotify" in cls:
            return "spotify"
        if "kitty" in cls:
            return "kitty"
        if "firefox" in cls:
            return "firefox"
        if "code" in cls:
            return "visual-studio-code"
        if "thunar" in cls:
            return "system-file-manager"
        return cls

    # 4. Construir entradas para rofi con protocolo nativo de iconos
    rofi_input_bytes = bytearray()
    for w in windows:
        ws_name = str(w.get("workspace", {}).get("name", ""))
        if ws_name.startswith("special:"):
            tag = "[Minimizada]"
        else:
            tag = f"[WS {ws_name}]"

        app_name = w.get("class") or "App"
        title = w.get("title") or ""
        
        # Limitar longitud del título para que se vea limpio
        if len(title) > 60:
            title = title[:57] + "..."

        display_text = f"{tag:<14} {app_name:<16} —  {title}"
        icon = get_icon(w)

        # Protocolo Rofi dmenu: texto\0icon\x1fnombre_icono\n
        line = f"{display_text}\0icon\x1f{icon}\n"
        rofi_input_bytes.extend(line.encode("utf-8"))

    # 5. Ejecutar Rofi con el tema personalizado
    theme_path = os.path.expanduser("~/.config/rofi/window-menu.rasi")
    cmd = [
        "rofi",
        "-dmenu",
        "-i",
        "-show-icons",
        "-p", "🪟 Ventanas",
        "-format", "i",
        "-theme", theme_path
    ]

    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    out, _ = proc.communicate(input=rofi_input_bytes)

    if proc.returncode != 0 or not out:
        sys.exit(0)

    try:
        selected_idx = int(out.decode("utf-8").strip())
        target_win = windows[selected_idx]
    except (ValueError, IndexError):
        sys.exit(0)

    target_addr = target_win.get("address")
    target_ws = target_win.get("workspace", {}).get("name", "")

    if not target_addr:
        sys.exit(0)

    # 6. Si está minimizada, restaurarla al espacio actual
    if target_ws == "special:minimized":
        lua_unmini = f"hl.dispatch(hl.dsp.window.move({{ address = '{target_addr}', workspace = '+0' }}))"
        subprocess.run(["hyprctl", "eval", lua_unmini], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # 7. Enfocar la ventana seleccionada
    lua_focus = f"hl.dispatch(hl.dsp.focus({{ window = 'address:{target_addr}' }}))"
    subprocess.run(["hyprctl", "eval", lua_focus], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

if __name__ == "__main__":
    main()
