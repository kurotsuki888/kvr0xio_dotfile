# Sistema de Wallpapers — Hyprland

## Estado actual: Fondos ESTÁTICOS (swaybg)

El sistema ahora usa **swaybg** para fondos de pantalla estáticos.
Las imágenes se buscan en `~/Imágenes/wallpapers/`.

---

## Scripts activos

### `set_wallpaper.sh`
Cambia el fondo de pantalla en todos los monitores usando `swaybg`.
- Mata instancias previas de swaybg
- Aplica el mismo fondo en `eDP-1` y `HDMI-A-1`
- Guarda el fondo actual en `~/.config/hypr/.current_wallpaper`

**Uso:**
```bash
~/.config/hypr/scripts/set_wallpaper.sh /ruta/a/imagen.jpg
```

### `wp_picker.sh`
Selector gráfico de fondos. Muestra los archivos de `~/Imágenes/wallpapers/`
y permite elegir uno visualmente.

**Atajo:** `Super + Alt + W`

---

## Scripts desactivados (se conservan como referencia)

### `init_wp.sh`
Inicializaba **mpvpaper** al arrancar para fondos de video animados.
Ya no se usa en exec-once de hyprland.conf (comentado).

### `wallpaper_control.sh`
Daemon que pausaba/reanudaba mpvpaper según si había ventanas
abiertas en cada monitor, para ahorrar GPU.
Ya no se necesita con fondos estáticos.

### `toggle_wallpaper_pause.sh`
Toggle manual de pausa de mpvpaper (bind: `Super+Shift+P`).
Ya no se necesita con fondos estáticos.

---

## ¿Por qué se cambió a fondos estáticos?

- `mpvpaper` con 2 monitores consumía ~2.5GB de VRAM de 3GB totales
  y mantenía la GPU al 70% incluso en pausa
- Esto causaba stutters y freezes al abrir Firefox u otras apps pesadas
- Con `swaybg` el consumo de GPU por el fondo es prácticamente 0%

---

## Añadir nuevos wallpapers

Solo copia imágenes (.jpg, .jpeg, .png) a:
```
~/Imágenes/wallpapers/
```
Y aparecerán automáticamente en el selector.
