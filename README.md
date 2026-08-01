```text
 _                 ___       _             _       _    __ _ _      
| | ____   ___ __ / _ \__  _(_) ___     __| | ___ | |_ / _(_) | ___ 
| |/ /\ \ / / '__| | | \ \/ / |/ _ \   / _` |/ _ \| __| |_| | |/ _ \
|   <  \ V /| |  | |_| |>  <| | (_) | | (_| | (_) | |_|  _| | |  __/
|_|\_\  \_/ |_|   \___//_/\_\_|\___/   \__,_|\___/ \__|_| |_|_|\___|
```

# 🦇 kvr0xio_dotfile

Mis configuraciones personalizadas para **Hyprland (con soporte nativo Lua y .conf tradicional)**, **Waybar**, **Quickshell**, **Kitty**, **Rofi**, **Fastfetch**, **Btop**, **Cava**, **GTK-3/4**, **Zsh** y **Powerlevel10k**, listas para instalar en cualquier sistema con una sola línea.

---

## 🎨 Componentes Incluidos

| Componente | Ruta | Descripción |
|---|---|---|
| **Hyprland (Lua)** | `~/.config/hypr/hyprland.lua` | Configuración oficial en formato Lua para Hyprland 0.56+ / 0.57+ |
| **Hyprland (Conf)** | `~/.config/hypr/hyprland.conf` | Backup en formato tradicional .conf |
| **Hyprlock** | `~/.config/hypr/hyprlock.conf` | Pantalla de bloqueo con foto de perfil y reloj |
| **Waybar** | `~/.config/waybar` | Barra superior con módulos y scripts interactivos |
| **Quickshell** | `~/.config/quickshell` | Powermenu, Wi-Fi, Bluetooth, Notificaciones, Calendario |
| **Kitty** | `~/.config/kitty` | Emulador de terminal configurado |
| **Rofi** | `~/.config/rofi` | Lanzador de aplicaciones y menús gráficos |
| **Fastfetch** | `~/.config/fastfetch` | Resumen del sistema con banner ASCII |
| **Btop & Cava** | `~/.config/btop`, `~/.config/cava` | Monitor del sistema y visualizador de audio en terminal |
| **Temas GTK** | `~/.config/gtk-3.0`, `~/.config/gtk-4.0` | Estilos oscuros `adw-gtk3-dark` |
| **Zsh + p10k** | `~/.zshrc`, `~/.p10k.zsh` | Shell con Powerlevel10k y plugins |

---

## 🚀 Instalación

```bash
git clone https://github.com/kurotsuki888/kvr0xio_dotfile.git ~/kvr0xio_dotfile
cd ~/kvr0xio_dotfile
./install.sh
```

El instalador verifica e instala automáticamente las dependencias faltantes, realiza respaldos de configuraciones previas, crea las carpetas necesarias y asegura que los scripts tengan permisos de ejecución.

---

## 📁 Carpetas del Sistema

El instalador crea las siguientes carpetas automáticamente:

| Carpeta | Propósito |
|---|---|
| `~/Vídeos/Wallpapers/` | **Wallpapers animados** — coloca aquí tus archivos `.mp4`, `.webm`, `.gif` para usar con `mpvpaper`. Se activan con `Super + Alt + W`. |
| `~/Imágenes/Wallpapers/` | **Wallpapers estáticos** — coloca aquí tus imágenes `.png`, `.jpg`. Se activan con el selector de fondos (`Super + Alt + W`). |
| `~/Pictures/screenshot/` | **Capturas de pantalla** — destino de `Super + Shift + S` (captura con selección de área). |
| `~/.config/hypr/` | **Configuración de Hyprland** — incluye `hyprland.lua`, `hyprland.conf`, scripts y `profile.png`. |

> **Foto de perfil**: coloca tu imagen en `~/.config/hypr/profile.png`.  
> También puedes cambiarla desde el **Powermenu → 🖼 Cambiar foto de perfil**.

---

## 🖼 Foto de Perfil

La foto de perfil es **única y compartida** entre el Powermenu y la pantalla de bloqueo (Hyprlock).

**Ruta estándar:** `~/.config/hypr/profile.png`

**Cómo configurarla:**

1. **Desde el Powermenu** (recomendado): abre el powermenu desde la waybar y haz clic en **🖼 Cambiar foto de perfil**. Se abrirá un selector de archivos para elegir tu imagen.
2. **Manualmente**: copia tu imagen a `~/.config/hypr/profile.png`.
   ```bash
   cp ~/tu-foto.png ~/.config/hypr/profile.png
   ```

> La foto *no se sube al repositorio* para respetar la privacidad. Cada usuario configura la suya después de instalar.

---

## 🎮 Controles de Uso

### Apps principales

| Atajo | Acción |
|---|---|
| `Super + Enter` | Abrir terminal (Kitty) |
| `Super + B` | Abrir navegador (Firefox) |
| `Super + E` | Abrir gestor de archivos (Thunar) |
| `Super + Space` | Abrir lanzador de apps (Rofi) |

### Gestión de ventanas

| Atajo | Acción |
|---|---|
| `Super + Q` | Cerrar ventana activa |
| `Super + Shift + Q` | Cerrar sesión de Hyprland |
| `Super + F` | Pantalla completa |
| `Super + V` | Alternar flotante |
| `Super + M` | Minimizar (enviar a workspace especial) |
| `Super + Shift + M` | Mostrar ventanas minimizadas |
| `Super + Shift + Enter` | Abrir Kitty con sesión dashboard |

### Navegación entre ventanas

| Atajo | Acción |
|---|---|
| `Super + ←/→/↑/↓` | Mover foco (flechas) |
| `Super + H/J/K/L` | Mover foco (vim-style) |
| `Super + Shift + ←/→/↑/↓` | Mover ventana |
| `Super + Ctrl + ←/→/↑/↓` | Redimensionar ventana |

### Workspaces

| Atajo | Acción |
|---|---|
| `Super + 1–0` | Ir al workspace 1–10 |
| `Super + Shift + 1–0` | Mover ventana al workspace 1–10 |
| `Super + Rueda del mouse` | Navegar entre workspaces |

### Multimedia

| Atajo | Acción |
|---|---|
| `XF86AudioRaiseVolume` | Subir volumen |
| `XF86AudioLowerVolume` | Bajar volumen |
| `XF86AudioMute` | Silenciar |
| `XF86AudioMicMute` | Silenciar micrófono |
| `XF86AudioPlay/Pause` | Play/Pausa |
| `XF86AudioNext/Prev` | Siguiente/Anterior |
| `XF86MonBrightnessUp/Down` | Brillo de pantalla |

### Captura de pantalla

| Atajo | Acción |
|---|---|
| `Print` | Capturar área seleccionada → portapapeles |
| `Super + Print` | Capturar pantalla completa → portapapeles |
| `Super + Shift + S` | Capturar área → guardar en `~/Pictures/screenshot/` |

### Utilidades

| Atajo | Acción |
|---|---|
| `Super + Shift + L` | Bloquear pantalla (Hyprlock) |
| `Super + C` | Historial del portapapeles (cliphist + Rofi) |
| `Super + Shift + W` | Recargar Waybar |
| `Super + Alt + W` | Abrir selector de fondos de pantalla |
| `Super + Shift + P` | Pausar/reanudar wallpaper animado (modo juego) |
| `Super + Shift + O` | Reanudar wallpaper animado |
| `Super + Mouse Izq.` | Mover ventana flotante |
| `Super + Mouse Der.` | Redimensionar ventana flotante |

---

## 🔧 Requisitos del Sistema

El instalador detecta automáticamente tu distribución (Arch/CachyOS/Fedora/Debian) e instala los paquetes faltantes.

**Dependencias principales:**

| Categoría | Paquetes |
|---|---|
| Compositor | `hyprland`, `hyprlock`, `hyprpaper`, `uwsm` |
| Barra y shell | `waybar`, `quickshell`, `swaync` |
| Lanzadores | `rofi-wayland`, `zenity` |
| Terminal y apps | `kitty`, `whatsie`, `thunar`, `firefox` |
| Fondo de pantalla | `swaybg`, `mpvpaper`, `mpv` |
| Audio | `pipewire`, `wireplumber`, `pavucontrol` |
| Multimedia | `playerctl`, `ffmpeg` |
| Capturas | `grim`, `slurp` |
| Portapapeles | `wl-clipboard`, `cliphist` |
| Red y BT | `network-manager-applet`, `blueman` |
| Shell & Utiles | `zsh`, `fzf`, `fastfetch`, `btop`, `cava`, `lsd`, `bat` |
| Tema GTK | `adw-gtk3` |

---

## 🐚 Post-instalación

Después de instalar, cambia tu shell a Zsh si no lo has hecho:

```bash
chsh -s $(which zsh)
```

Luego reinicia la sesión para aplicar todos los cambios.
