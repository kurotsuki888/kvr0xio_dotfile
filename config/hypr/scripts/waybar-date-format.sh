#!/usr/bin/env bash
# Formatea la fecha como "Martes, 21 de julio" para waybar

d=$(LC_TIME=es_ES.UTF-8 date '+%A, %d de %B' 2>/dev/null)

# Si el locale es_ES no está instalado, cae a formato numérico simple
if [[ -z "$d" ]]; then
    d=$(date '+%d/%m/%Y')
    echo "$d"
    exit 0
fi

# Capitaliza la primera letra (martes -> Martes)
echo "${d^}"
