#!/bin/bash
# Recibe la ruta absoluta del archivo
FILE="$1"

# Construimos el comando IPC usando jq para evitar errores de sintaxis
JSON=$(jq -n --arg file "$FILE" '{command: ["loadfile", $file]}')

# Inyectamos a los sockets de ambos monitores
echo "$JSON" | socat - /tmp/mpvpaper-eDP1.sock > /dev/null 2>&1
echo "$JSON" | socat - /tmp/mpvpaper-HDMI.sock > /dev/null 2>&1
