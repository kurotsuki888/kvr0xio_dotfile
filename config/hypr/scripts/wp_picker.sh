#!/bin/bash
shopt -s nullglob nocaseglob

WP_DIR="$HOME/Imágenes/wallpapers"
CACHE_DIR="$HOME/.cache/wp_thumbnails"
STATE_FILE="$HOME/.config/hypr/.current_wallpaper"

THUMB_W=140
THUMB_H=$THUMB_W
SPACING=10
MAX_COLUMNS=3

mkdir -p "$WP_DIR"
mkdir -p "$CACHE_DIR"

FILES=("$WP_DIR"/*.{jpg,jpeg,png,webp})

if [ ${#FILES[@]} -eq 0 ]; then
    rofi -e "Directorio vacío o ruta incorrecta: $WP_DIR"
    exit 1
fi

ROFI_LIST=""
VALID_COUNT=0

for file in "${FILES[@]}"; do
    [ -f "$file" ] || continue
    filename=$(basename "$file")
    thumb="$CACHE_DIR/${filename}.${THUMB_W}x${THUMB_H}.jpg"

    # Generar miniatura si no existe
    if [ ! -s "$thumb" ]; then
        ffmpeg -y -i "$file" \
            -vf "scale=${THUMB_W}:${THUMB_H}:force_original_aspect_ratio=increase,crop=${THUMB_W}:${THUMB_H}" \
            "$thumb" -loglevel error
        if [ ! -s "$thumb" ]; then
            echo "wp_picker: no se pudo generar miniatura para '$filename'" >&2
            rm -f "$thumb"
            continue
        fi
    fi

    ROFI_LIST+="${filename}\0icon\x1f${thumb}\n"
    VALID_COUNT=$((VALID_COUNT + 1))
done

TOTAL=$VALID_COUNT

if [ "$TOTAL" -eq 0 ]; then
    rofi -e "No se pudo generar ninguna miniatura en $WP_DIR"
    exit 1
fi

VISIBLE_ITEMS=$MAX_COLUMNS
[ "$TOTAL" -lt "$MAX_COLUMNS" ] && VISIBLE_ITEMS=$TOTAL

WINDOW_PADDING=12
WINDOW_BORDER=1
ELEMENT_OUTER_W=$(( THUMB_W + 4 ))
WINDOW_WIDTH=$(( ELEMENT_OUTER_W * VISIBLE_ITEMS + SPACING * (VISIBLE_ITEMS - 1) + WINDOW_PADDING * 2 + WINDOW_BORDER * 2 ))

# Paleta Catppuccin Mocha
BASE="#1e1e2ef2"
SURFACE1="#45475a"
BLUE="#89b4fa"
TEXT="#cdd6f4"

THEME="
* { font: \"Sans 9\"; text-color: ${TEXT}; margin: 0px; }
window {
    location: south; anchor: south; y-offset: 30px;
    width: ${WINDOW_WIDTH}px;
    border: ${WINDOW_BORDER}px; border-radius: 12px;
    border-color: ${SURFACE1}; background-color: ${BASE};
    padding: ${WINDOW_PADDING}px;
}
mainbox {
    spacing: 8px; padding: 0px;
    background-color: transparent;
}
inputbar { enabled: false; }
listview {
    background-color: transparent;
    layout: horizontal;
    lines: ${VISIBLE_ITEMS};
    spacing: ${SPACING}px;
    padding: 0px;
    fixed-height: true;
    scrollbar: false;
}
element {
    background-color: transparent;
    padding: 0px; orientation: vertical; border-radius: 8px;
    border: 2px; border-color: transparent;
    width: ${THUMB_W}px; height: ${THUMB_H}px;
}
element-icon {
    background-color: transparent;
    size: ${THUMB_W}px;
    horizontal-align: 0.5; vertical-align: 0.5;
    border-radius: 6px;
}
element-text { enabled: false; }
element selected { background-color: ${BLUE}33; border-color: ${BLUE}; }
message {
    padding: 0px 0px 8px 0px;
    background-color: transparent;
    border: 0px;
    horizontal-align: 0.5;
}
textbox {
    text-color: ${TEXT};
    background-color: transparent;
    horizontal-align: 0.5;
}
"

SELECTED=$(echo -en "$ROFI_LIST" | rofi -no-config -dmenu -i -show-icons -theme-str "$THEME" -mesg "$TOTAL fondos disponibles")

if [ -n "$SELECTED" ]; then
    FILE="$WP_DIR/$SELECTED"
    ~/.config/hypr/scripts/set_wallpaper.sh "$FILE"
fi
