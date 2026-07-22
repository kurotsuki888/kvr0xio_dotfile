#!/usr/bin/env bash

# Installation script for kvr0xio_dotfile
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Iniciando instalación de kvr0xio_dotfile..."

# -----------------------------------------------------------------------------
# 1. Helper functions & Package Detection
# -----------------------------------------------------------------------------
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Array de dependencias a verificar (comando:nombre_paquete_fedora:nombre_paquete_arch:nombre_paquete_debian)
DEPENDENCIES=(
    "hyprland:hyprland:hyprland:hyprland"
    "hyprlock:hyprlock:hyprlock:hyprlock"
    "waybar:waybar:waybar:waybar"
    "rofi:rofi-wayland:rofi-wayland:rofi"
    "dunst:dunst:dunst:dunst"
    "kitty:kitty:kitty:kitty"
    "firefox:firefox:firefox:firefox"
    "dolphin:dolphin:dolphin:dolphin"
    "pavucontrol:pavucontrol:pavucontrol:pavucontrol"
    "brightnessctl:brightnessctl:brightnessctl:brightnessctl"
    "grim:grim:grim:grim"
    "slurp:slurp:slurp:slurp"
    "wl-copy:wl-clipboard:wl-clipboard:wl-clipboard"
    "cliphist:cliphist:cliphist:cliphist"
    "mpv:mpv:mpv:mpv"
    "mpvpaper:mpvpaper:mpvpaper:mpvpaper"
    "socat:socat:socat:socat"
    "ffmpeg:ffmpeg:ffmpeg:ffmpeg"
    "jq:jq:jq:jq"
    "zsh:zsh:zsh:zsh"
    "git:git:git:git"
    "curl:curl:curl:curl"
    "fzf:fzf:fzf:fzf"
    "lsd:lsd:lsd:lsd"
    "bat:bat:bat:bat"
    "fastfetch:fastfetch:fastfetch:fastfetch"
    "yazi:yazi:yazi:yazi"
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
        
        if [ -n "$pkg" ]; then
            # Evitar duplicados
            if [[ ! " ${MISSING_PACKAGES[*]} " =~ " ${pkg} " ]]; then
                MISSING_PACKAGES+=("$pkg")
            fi
        fi
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo "📦 Se encontraron aplicaciones faltantes: ${MISSING_PACKAGES[*]}"
    echo "⚙️ Instalando dependencias con $PM..."
    
    case $PM in
        dnf)
            sudo dnf install -y "${MISSING_PACKAGES[@]}" || echo "⚠️ Algunos paquetes no pudieron instalarse automáticamente con dnf. Continuando..."
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
            sudo apt update && sudo apt install -y "${MISSING_PACKAGES[@]}" || echo "⚠️ Algunos paquetes no pudieron instalarse automáticamente con apt. Continuando..."
            ;;
        *)
            echo "⚠️ No se detectó un gestor de paquetes soportado ($PM). Por favor instala manualmente: ${MISSING_PACKAGES[*]}"
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

# Crear directorio de fondos por defecto si no existe
mkdir -p "$HOME/Vídeos/Wallpapers"

# -----------------------------------------------------------------------------
# 3. Copy Config Files
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

echo "✨ ¡Instalación y configuración completadas con éxito!"

