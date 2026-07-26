#!/usr/bin/env bash

# Installation script for kvr0xio_dotfile
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Iniciando instalación de kvr0xio_dotfile..."

# -----------------------------------------------------------------------------
# 1. Helper functions & Package Detection
# -----------------------------------------------------------------------------
command_exists() {
    command -v "$1" > /dev/null 2>&1
}

# Array de dependencias a verificar (comando:nombre_paquete_fedora:nombre_paquete_arch:nombre_paquete_debian)
DEPENDENCIES=(
    # --- Compositor y entorno Wayland ---
    "hyprland:hyprland:hyprland:hyprland"
    "hyprlock:hyprlock:hyprlock:hyprlock"
    "hyprpaper:hyprpaper:hyprpaper:hyprpaper"
    "uwsm:uwsm:uwsm:uwsm"
    # --- Barra y shell ---
    "waybar:waybar:waybar:waybar"
    "quickshell:quickshell:quickshell:quickshell"
    # --- Lanzadores y menús ---
    "rofi:rofi-wayland:rofi-wayland:rofi"
    "zenity:zenity:zenity:zenity"
    # --- Notificaciones ---
    "dunst:dunst:dunst:dunst"
    # --- Terminal ---
    "kitty:kitty:kitty:kitty"
    # --- Navegador y apps ---
    "firefox:firefox:firefox:firefox"
    "thunar:thunar:thunar:thunar"
    "pavucontrol:pavucontrol:pavucontrol:pavucontrol"
    # --- Fondo de pantalla ---
    "swaybg:swaybg:swaybg:swaybg"
    "mpvpaper:mpvpaper:mpvpaper:mpvpaper"
    "mpv:mpv:mpv:mpv"
    # --- Brillo y multimedia ---
    "brightnessctl:brightnessctl:brightnessctl:brightnessctl"
    "playerctl:playerctl:playerctl:playerctl"
    "wpctl:wireplumber:wireplumber:wireplumber"
    # --- Capturas de pantalla ---
    "grim:grim:grim:grim"
    "slurp:slurp:slurp:slurp"
    # --- Portapapeles ---
    "wl-copy:wl-clipboard:wl-clipboard:wl-clipboard"
    "cliphist:cliphist:cliphist:cliphist"
    # --- Portales XDG ---
    "xdg-desktop-portal:xdg-desktop-portal:xdg-desktop-portal:xdg-desktop-portal"
    # --- Multimedia y procesamiento ---
    "socat:socat:socat:socat"
    "ffmpeg:ffmpeg:ffmpeg:ffmpeg"
    "jq:jq:jq:jq"
    # --- Shell y utilidades ---
    "zsh:zsh:zsh:zsh"
    "git:git:git:git"
    "curl:curl:curl:curl"
    "fzf:fzf:fzf:fzf"
    "lsd:lsd:lsd:lsd"
    "bat:bat:bat:bat"
    "fastfetch:fastfetch:fastfetch:fastfetch"
    "yazi:yazi:yazi:yazi"
    # --- Red ---
    "nm-applet:network-manager-applet:network-manager-applet:network-manager-gnome"
    "blueman-manager:blueman:blueman:blueman"
    # --- Audio ---
    "pipewire:pipewire:pipewire:pipewire"
    "wireplumber:wireplumber:wireplumber:wireplumber"
    # --- Tema GTK ---
    "adw-gtk3-dark::adw-gtk3::adw-gtk3"
)

PM=""
PM_INDEX=1 # 1: fedora, 2: arch, 3: debian

if command_exists dnf; then
    PM="dnf"
    PM_INDEX=1
elif command_exists pacman; then
    PM="pacman"
    PM_INDEX=2
elif command_exists apt-get || command_exists apt; then
    PM="apt"
    PM_INDEX=3
fi

MISSING_PACKAGES=()

echo "🔍 Verificando aplicaciones y herramientas necesarias..."

for entry in "${DEPENDENCIES[@]}"; do
    IFS=":" read -r cmd pkg_fedora pkg_arch pkg_debian <<< "$entry"

    if ! command_exists "$cmd"; then
        case $PM_INDEX in
            1) pkg="$pkg_fedora" ;;
            2) pkg="$pkg_arch" ;;
            3) pkg="$pkg_debian" ;;
            *) pkg="" ;;
        esac

        # Saltar paquetes vacíos (sin soporte en esa distro)
        [ -z "$pkg" ] && continue

        # Evitar duplicados
        if [[ ! " ${MISSING_PACKAGES[*]} " =~ " ${pkg} " ]]; then
            MISSING_PACKAGES+=("$pkg")
        fi
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo "📦 Se encontraron aplicaciones faltantes: ${MISSING_PACKAGES[*]}"
    echo "⚙️  Instalando dependencias con $PM..."

    case $PM in
        dnf)
            sudo dnf install -y "${MISSING_PACKAGES[@]}" || echo "⚠️  Algunos paquetes no pudieron instalarse automáticamente con dnf. Continuando..."
            ;;
        pacman)
            if command_exists yay; then
                yay -S --needed --noconfirm "${MISSING_PACKAGES[@]}" || true
            elif command_exists paru; then
                paru -S --needed --noconfirm "${MISSING_PACKAGES[@]}" || true
            else
                sudo pacman -S --needed --noconfirm "${MISSING_PACKAGES[@]}" || true
            fi
            ;;
        apt)
            sudo apt update && sudo apt install -y "${MISSING_PACKAGES[@]}" || echo "⚠️  Algunos paquetes no pudieron instalarse automáticamente con apt. Continuando..."
            ;;
        *)
            echo "⚠️  No se detectó un gestor de paquetes soportado. Instala manualmente: ${MISSING_PACKAGES[*]}"
            ;;
    esac
else
    echo "✅ Todas las aplicaciones necesarias ya están instaladas."
fi

# -----------------------------------------------------------------------------
# 2. Oh My Zsh, Powerlevel10k & Plugins Setup
# -----------------------------------------------------------------------------
echo "🐚 Verificando configuración de Zsh, Oh My Zsh y plugins..."

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "  -> Instalando Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    echo "  -> Clonando tema Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k" || true
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo "  -> Clonando plugin zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" || true
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo "  -> Clonando plugin zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" || true
fi

# -----------------------------------------------------------------------------
# 3. Crear carpetas necesarias
# -----------------------------------------------------------------------------
echo "📁 Creando carpetas necesarias..."

# Carpetas de wallpapers
mkdir -p "$HOME/Vídeos/Wallpapers"
echo "  -> ~/Vídeos/Wallpapers           (wallpapers animados para mpvpaper)"

mkdir -p "$HOME/Imágenes/Wallpapers"
echo "  -> ~/Imágenes/Wallpapers         (wallpapers estáticos para swaybg)"

# Carpetas de capturas de pantalla
mkdir -p "$HOME/Imágenes/Screenshots"
echo "  -> ~/Imágenes/Screenshots        (capturas de pantalla con Super+Shift+S)"

# Carpeta de configuración de Hyprland (para profile.png)
mkdir -p "$HOME/.config/hypr"
echo "  -> ~/.config/hypr                (configuración de Hyprland)"

# Otras carpetas de configuración
mkdir -p "$HOME/.config"

# -----------------------------------------------------------------------------
# 4. Foto de perfil
# -----------------------------------------------------------------------------
echo ""
echo "🖼  Configurando foto de perfil..."

PROFILE_PATH="$HOME/.config/hypr/profile.png"

if [ ! -f "$PROFILE_PATH" ]; then
    echo ""
    echo "  ┌─────────────────────────────────────────────────────────────┐"
    echo "  │  ⚠️  No se encontró foto de perfil                          │"
    echo "  │                                                             │"
    echo "  │  Coloca tu foto en:                                         │"
    echo "  │    ~/.config/hypr/profile.png                              │"
    echo "  │                                                             │"
    echo "  │  O usa el botón '🖼 Cambiar foto de perfil' del Powermenu   │"
    echo "  │  (accesible desde la waybar) para elegirla gráficamente.   │"
    echo "  │                                                             │"
    echo "  │  Formatos soportados: .png, .jpg, .jpeg, .webp             │"
    echo "  └─────────────────────────────────────────────────────────────┘"
    echo ""
else
    echo "  -> Foto de perfil encontrada en $PROFILE_PATH ✅"
fi

# -----------------------------------------------------------------------------
# 5. Copy Config Files
# -----------------------------------------------------------------------------
echo "📂 Copiando archivos de configuración..."

mkdir -p ~/.config

# Copy .config entries
if [ -d "$DOTFILES_DIR/config" ]; then
    for item in "$DOTFILES_DIR/config/"*; do
        if [ -e "$item" ]; then
            target="$HOME/.config/$(basename "$item")"
            echo "  -> Copiando $(basename "$item") a ~/.config/"
            cp -rf "$item" ~/.config/
        fi
    done
fi

# Copy Zsh configs
if [ -f "$DOTFILES_DIR/zshrc" ]; then
    echo "  -> Copiando .zshrc"
    cp -f "$DOTFILES_DIR/zshrc" ~/.zshrc
fi

if [ -f "$DOTFILES_DIR/p10k.zsh" ]; then
    echo "  -> Copiando .p10k.zsh"
    cp -f "$DOTFILES_DIR/p10k.zsh" ~/.p10k.zsh
fi

# -----------------------------------------------------------------------------
# 6. Resumen final
# -----------------------------------------------------------------------------
echo ""
echo "✨ ¡Instalación completada con éxito!"
echo ""
echo "📋 Próximos pasos:"
echo "   1. Coloca tu foto de perfil en ~/.config/hypr/profile.png"
echo "      (o usa el botón 🖼 del Powermenu para elegirla)"
echo "   2. Agrega wallpapers en ~/Vídeos/Wallpapers  (animados)"
echo "      o en          ~/Imágenes/Wallpapers (estáticos)"
echo "   3. Cambia el shell a zsh:  chsh -s \$(which zsh)"
echo "   4. Reinicia la sesión para aplicar todos los cambios."
echo ""
