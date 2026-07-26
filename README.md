# ⚡ kvr0xio_dotfile

Mis configuraciones personalizadas para **Hyprland**, **Waybar**, **Quickshell**, **Kitty**, **Rofi**, **Zsh** y **Powerlevel10k**, listas para instalar en cualquier sistema con una sola línea.

---

## 🎨 Componentes Incluidos

| Componente | Ruta | Descripción |
|---|---|---|
| **Hyprland** | `~/.config/hypr` | Compositor Wayland — ventanas, animaciones, atajos y reglas |
| **Hyprlock** | `~/.config/hypr/hyprlock.conf` | Pantalla de bloqueo con foto de perfil y reloj |
| **Waybar** | `~/.config/waybar` | Barra superior con módulos y scripts interactivos |
| **Quickshell** | `~/.config/quickshell` | Powermenu, Wi-Fi, Bluetooth, Notificaciones, Calendario |
| **Kitty** | `~/.config/kitty` | Emulador de terminal configurado |
| **Rofi** | `~/.config/rofi` | Lanzador de aplicaciones y menús gráficos |
| **Zsh + p10k** | `~/.zshrc`, `~/.p10k.zsh` | Shell con Powerlevel10k y plugins |

---

## 🚀 Instalación

```bash
git clone https://github.com/kurotsuki888/kvr0xio_dotfile.git ~/kvr0xio_dotfile
cd ~/kvr0xio_dotfile
./install.sh
```

El instalador verifica e instala automáticamente las dependencias faltantes, crea las carpetas necesarias y te avisa si falta la foto de perfil.

---

## 📁 Carpetas del Sistema

El instalador crea las siguientes carpetas automáticamente:

| Carpeta | Propósito |
|---|---|
| `~/Vídeos/Wallpapers/` | **Wallpapers animados** — coloca aquí tus archivos `.mp4`, `.webm`, `.gif` para usar con `mpvpaper`. Se activan con `Super + Alt + W`. |
| `~/Imágenes/Wallpapers/` | **Wallpapers estáticos** — coloca aquí tus imágenes `.png`, `.jpg`. Se activan con el selector de fondos (`Super + Alt + W`). |
| `~/Imágenes/Screenshots/` | **Capturas de pantalla** — destino de `Super + Shift + S` (captura con selección de área). |
| `~/.config/hypr/` | **Configuración de Hyprland** — incluye `profile.png` (foto de perfil usada en powermenu e hyprlock). |

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
| `Super + Shift + S` | Capturar área → guardar en `~/Imágenes/Screenshots/` |

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

El instalador detecta automáticamente tu distribución (Fedora/Arch/Debian) e instala los paquetes faltantes.

**Dependencias principales:**

| Categoría | Paquetes |
|---|---|
| Compositor | `hyprland`, `hyprlock`, `hyprpaper`, `uwsm` |
| Barra y shell | `waybar`, `quickshell` |
| Lanzadores | `rofi-wayland`, `zenity` |
| Terminal | `kitty` |
| Fondo de pantalla | `swaybg`, `mpvpaper`, `mpv` |
| Audio | `pipewire`, `wireplumber`, `pavucontrol` |
| Multimedia | `playerctl`, `ffmpeg` |
| Capturas | `grim`, `slurp` |
| Portapapeles | `wl-clipboard`, `cliphist` |
| Red y BT | `network-manager-applet`, `blueman` |
| Shell | `zsh`, `fzf`, `lsd`, `bat`, `yazi`, `fastfetch` |
| Tema GTK | `adw-gtk3` |
| Utiles | `git`, `curl`, `jq`, `socat`, `brightnessctl` |

---

## 🐚 Post-instalación

Después de instalar, cambia tu shell a Zsh si no lo has hecho:

```bash
chsh -s $(which zsh)
```

Luego reinicia la sesión para que todos los cambios tomen efecto.
