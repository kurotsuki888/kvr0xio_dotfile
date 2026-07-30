#!/bin/bash
# set_wallpaper.sh — Fondo de pantalla estático con swaybg
# Busca imágenes en ~/Imágenes/wallpapers/
#
# Uso:
#   set_wallpaper.sh /ruta/a/imagen.jpg   → aplica esa imagen
#   set_wallpaper.sh                      → aplica el último fondo guardado

STATE_FILE="$HOME/.config/hypr/.current_wallpaper"
WALLPAPER_DIR="$HOME/Imágenes/wallpapers"

# Resolver qué imagen usar
if [ -n "${1:-}" ]; then
    TARGET_WP="$1"
else
    # Sin argumento: usar el último fondo guardado, o uno al azar si no hay
    if [ -f "$STATE_FILE" ] && [ -f "$(cat "$STATE_FILE")" ]; then
        TARGET_WP=$(cat "$STATE_FILE")
    else
        TARGET_WP=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n 1)
    fi
fi

[ -f "$TARGET_WP" ] || { echo "Archivo no existe: $TARGET_WP" >&2; exit 1; }

# Matar instancias previas de swaybg
pkill -x swaybg 2>/dev/null || true
sleep 0.2

# Aplicar en todos los monitores en paralelo
swaybg -i "$TARGET_WP" -m fill &

# Guardar el fondo actual
echo "$TARGET_WP" > "$STATE_FILE"
echo "✓ Fondo aplicado: $(basename "$TARGET_WP")"
