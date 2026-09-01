#!/usr/bin/env python3
import os
import subprocess
import sys

if not os.environ.get("WAYLAND_DISPLAY"):
    try:
        runtime_dir = f"/run/user/{os.getuid()}"
        wayland_displays = [f for f in os.listdir(runtime_dir) if f.startswith("wayland-")]
        if wayland_displays:
            os.environ["WAYLAND_DISPLAY"] = wayland_displays[0]
    except Exception:
        pass

CLEAR_OPTION = "🗑️  [Limpiar todo el historial]"
CACHE_DIR = os.path.expanduser("~/.cache/cliphist/thumbnails")
os.makedirs(CACHE_DIR, exist_ok=True)

def get_items():
    p = subprocess.Popen(["cliphist", "list"], stdout=subprocess.PIPE, text=True, errors="replace")
    out, _ = p.communicate()
    
    entries = []
    # Opción para limpiar
    entries.append(f"{CLEAR_OPTION}\0icon\x1fedit-delete")
    
    for line in out.splitlines():
        if not line:
            continue
        parts = line.split("\t", 1)
        clip_id = parts[0]
        preview = parts[1] if len(parts) > 1 else ""
        
        if "binary data" in preview:
            thumb_path = os.path.join(CACHE_DIR, f"{clip_id}.png")
            if not os.path.exists(thumb_path):
                try:
                    dec = subprocess.Popen(["cliphist", "decode", clip_id], stdout=subprocess.PIPE)
                    img_data, _ = dec.communicate()
                    if img_data:
                        with open(thumb_path, "wb") as f:
                            f.write(img_data)
                except Exception:
                    pass
            if os.path.exists(thumb_path):
                entries.append(f"{line}\0icon\x1f{thumb_path}")
            else:
                entries.append(line)
        else:
            entries.append(line)
    return "\n".join(entries)

def main():
    items = get_items()
    rofi = subprocess.Popen(
        [
            "rofi",
            "-dmenu",
            "-show-icons",
            "-p", "Portapapeles"
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        text=True,
        errors="replace"
    )
    selected, _ = rofi.communicate(input=items)
    
    if not selected:
        sys.exit(0)
        
    selected = selected.strip()
    
    if selected.startswith(CLEAR_OPTION):
        subprocess.run(["cliphist", "wipe"])
        db_path = os.path.expanduser("~/.cache/cliphist/db")
        if os.path.exists(db_path):
            try:
                os.remove(db_path)
            except Exception:
                pass
        # Limpiar miniaturas
        if os.path.exists(CACHE_DIR):
            for f in os.listdir(CACHE_DIR):
                try:
                    os.remove(os.path.join(CACHE_DIR, f))
                except Exception:
                    pass
        subprocess.run(["wl-copy", "--clear"])
        subprocess.run(["notify-send", "-u", "normal", "Portapapeles", "Historial vaciado"])
    else:
        # Decodificar y copiar al portapapeles
        p_decode = subprocess.Popen(["cliphist", "decode"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        out, _ = p_decode.communicate(input=selected.encode("utf-8"))
        p_copy = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE)
        p_copy.communicate(input=out)

if __name__ == "__main__":
    main()
