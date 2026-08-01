#!/usr/bin/env bash

# ==============================================================================
#  Installer script for kvr0xio_dotfile
#  Dotfiles for Hyprland (Lua & Conf), Waybar, Quickshell, Rofi, Kitty & Zsh
# ==============================================================================

set -e

# Terminal colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BOLD}${CYAN}"
echo "  _                    0_v_0       _        _        d---b "
echo " | | \ \ / / | __ ___  |_ _| ___  __| | ___ | |_ / _|/ __/ "
echo " | |/ / \ V /| '__/ _ \  | |/ _ \/ _\` |/ _ \|  _| |_ | (__ "
echo " |___/   \_/ |_|  \___/ |___|\___/\__,_|\___/|_| |_(_)____|"
echo -e "${NC}"
echo -e "${BOLD}${BLUE}🚀 Iniciando instalación de kvr0xio_dotfile...${NC}\n"

# -----------------------------------------------------------------------------
# 1. Helper functions & Package Detection
# -----------------------------------------------------------------------------
command_exists() {
    command -v "$1" > /dev/null 2>&1
}

# Array de dependencias: "comando:paquete_fedora:paquete_arch:paquete_debian"
DEPENDENCIES=(
    # --- Compositor y gestores Hypr ---
    "hyprland:hyprland:hyprland:hyprland"
    "hyprlock:hyprlock:hyprlock:hyprlock"
    "hyprpaper:hyprpaper:hyprpaper:hyprpaper"
    # --- Barra y Shell visual ---
    "waybar:waybar:waybar:waybar"
    "quickshell:quickshell:quickshell:quickshell"
    "swaync:swaync:swaync:swaync"
    # --- Lanzadores y menús ---
    "rofi:rofi-wayland:rofi-wayland:rofi"
    "zenity:zenity:zenity:zenity"
    # --- Terminal ---
    "kitty:kitty:kitty:kitty"
    # --- Aplicaciones por defecto ---
    "firefox:firefox:firefox:firefox"
    "thunar:thunar:thunar:thunar"
    "pavucontrol:pavucontrol:pavucontrol:pavucontrol"
    "whatsie:whatsie:whatsie:whatsie"
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
    # --- Portales XDG y utilidades ---
    "xdg-desktop-portal:xdg-desktop-portal:xdg-desktop-portal:xdg-desktop-portal"
    "socat:socat:socat:socat"
    "ffmpeg:ffmpeg:ffmpeg:ffmpeg"
    "jq:jq:jq:jq"
    # --- Shell y terminal ---
    "zsh:zsh:zsh:zsh"
    "git:git:git:git"
    "curl:curl:curl:curl"
    "fzf:fzf:fzf:fzf"
    "fastfetch:fastfetch:fastfetch:fastfetch"
    "btop:btop:btop:btop"
    "cava:cava:cava:cava"
    # --- Red y Bluetooth ---
    "nm-applet:network-manager-applet:network-manager-applet:network-manager-gnome"
    "blueman-manager:blueman:blueman:blueman"
    # --- Audio ---
    "pipewire:pipewire:pipewire:pipewire"
    "wireplumber:wireplumber:wireplumber:wireplumber"
)

PM=""
PM_INDEX=1 # 1: fedora, 2: arch, 3: debian

if command_exists pacman; then
    PM="pacman"
    PM_INDEX=2
elif command_exists dnf; then
    PM="dnf"
    PM_INDEX=1
elif command_exists apt-get || command_exists apt; then
    PM="apt"
    PM_INDEX=3
fi

MISSING_PACKAGES=()

echo -e "${YELLOW}🔍 Verificando aplicaciones y herramientas necesarias...${NC}"

for entry in "${DEPENDENCIES[@]}"; do
    IFS=":" read -r cmd pkg_fedora pkg_arch pkg_debian <<< "$entry"

    if ! command_exists "$cmd"; then
        case $PM_INDEX in
            1) pkg="$pkg_fedora" ;;
            2) pkg="$pkg_arch" ;;
            3) pkg="$pkg_debian" ;;
            *) pkg="" ;;
        esac

        [ -z "$pkg" ] && continue

        if [[ ! " ${MISSING_PACKAGES[*]} " =~ " ${pkg} " ]]; then
            MISSING_PACKAGES+=("$pkg")
        fi
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo -e "${CYAN}📦 Paquetes sugeridos no encontrados: ${MISSING_PACKAGES[*]}${NC}"
    echo -e "${YELLOW}⚙️  Intentando instalar con gestor de paquetes ($PM)...${NC}"

    case $PM in
        pacman)
            if command_exists yay; then
                yay -S --needed --noconfirm "${MISSING_PACKAGES[@]}" || true
            elif command_exists paru; then
                paru -S --needed --noconfirm "${MISSING_PACKAGES[@]}" || true
            else
                sudo pacman -S --needed --noconfirm "${MISSING_PACKAGES[@]}" || true
            fi
            ;;
        dnf)
            sudo dnf install -y "${MISSING_PACKAGES[@]}" || echo -e "${YELLOW}⚠️  Algunos paquetes opcionales no pudieron instalarse con dnf. Continuando...${NC}"
            ;;
        apt)
            sudo apt update && sudo apt install -y "${MISSING_PACKAGES[@]}" || echo -e "${YELLOW}⚠️  Algunos paquetes no pudieron instalarse con apt. Continuando...${NC}"
            ;;
        *)
            echo -e "${YELLOW}⚠️  No se detectó un gestor de paquetes soportado. Instala manualmente: ${MISSING_PACKAGES[*]}${NC}"
            ;;
    esac
else
    echo -e "${GREEN}✅ Todas las herramientas requeridas ya están instaladas en el sistema.${NC}"
fi

# -----------------------------------------------------------------------------
# 2. Setup Zsh, Oh My Zsh & Plugins
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}🐚 Verificando entorno Zsh y Oh My Zsh...${NC}"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${CYAN}  -> Instalando Oh My Zsh...${NC}"
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    echo -e "${CYAN}  -> Instalando tema Powerlevel10k...${NC}"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k" || true
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo -e "${CYAN}  -> Instalando plugin zsh-autosuggestions...${NC}"
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" || true
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo -e "${CYAN}  -> Instalando plugin zsh-syntax-highlighting...${NC}"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" || true
fi

# -----------------------------------------------------------------------------
# 3. Directorios necesarios
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}📁 Creando estructura de directorios...${NC}"

mkdir -p "$HOME/Vídeos/Wallpapers"
echo "  -> ~/Vídeos/Wallpapers           (Wallpapers animados mpvpaper)"

mkdir -p "$HOME/Imágenes/Wallpapers"
echo "  -> ~/Imágenes/Wallpapers         (Wallpapers estáticos swaybg)"

mkdir -p "$HOME/Pictures/screenshot"
mkdir -p "$HOME/Pictures/Screenshots"
echo "  -> ~/Pictures/screenshot         (Capturas de pantalla)"

mkdir -p "$HOME/.config"

# Backup preventivo de configuraciones existentes
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
if [ -d "$HOME/.config/hypr" ]; then
    echo -e "${CYAN}  -> Creando respaldo preventivo en ~/.config/hypr.bak.${TIMESTAMP}${NC}"
    cp -rf "$HOME/.config/hypr" "$HOME/.config/hypr.bak.${TIMESTAMP}"
fi

# -----------------------------------------------------------------------------
# 4. Copia de configuraciones
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}📂 Desplegando archivos de configuración en ~/.config/...${NC}"

if [ -d "$DOTFILES_DIR/config" ]; then
    for item in "$DOTFILES_DIR/config/"*; do
        if [ -e "$item" ]; then
            base_name=$(basename "$item")
            echo -e "${GREEN}  -> Instalando ~/.config/${base_name}${NC}"
            cp -rf "$item" "$HOME/.config/"
        fi
    done
fi

# Hacer ejecutables todos los scripts
if [ -d "$HOME/.config/hypr/scripts" ]; then
    chmod +x "$HOME/.config/hypr/scripts/"*.sh 2>/dev/null || true
    chmod +x "$HOME/.config/hypr/scripts/"*.py 2>/dev/null || true
fi
if [ -d "$HOME/.config/waybar/scripts" ]; then
    chmod +x "$HOME/.config/waybar/scripts/"*.sh 2>/dev/null || true
    chmod +x "$HOME/.config/waybar/scripts/"*.py 2>/dev/null || true
fi

# Copiar archivos Zsh
if [ -f "$DOTFILES_DIR/zshrc" ]; then
    echo -e "${GREEN}  -> Copiando ~/.zshrc${NC}"
    cp -f "$DOTFILES_DIR/zshrc" "$HOME/.zshrc"
fi

if [ -f "$DOTFILES_DIR/p10k.zsh" ]; then
    echo -e "${GREEN}  -> Copiando ~/.p10k.zsh${NC}"
    cp -f "$DOTFILES_DIR/p10k.zsh" "$HOME/.p10k.zsh"
fi

# -----------------------------------------------------------------------------
# 5. Foto de Perfil
# -----------------------------------------------------------------------------
PROFILE_PATH="$HOME/.config/hypr/profile.png"
if [ ! -f "$PROFILE_PATH" ]; then
    echo -e "\n${YELLOW}🖼  Falta foto de perfil en $PROFILE_PATH${NC}"
    echo "   Puedes colocar tu foto en ~/.config/hypr/profile.png o usar el Powermenu."
else
    echo -e "\n${GREEN}🖼  Foto de perfil verificada en $PROFILE_PATH${NC}"
fi

# -----------------------------------------------------------------------------
# 6. Resumen y Finalización
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}${GREEN}✨ ¡Instalación de kvr0xio_dotfile completada con éxito!${NC}"
echo -e "${CYAN}------------------------------------------------------------${NC}"
echo -e " Configuración Hyprland Lua habilitada: ${BOLD}~/.config/hypr/hyprland.lua${NC}"
echo -e " Configuración Hyprland Conf backup:   ${BOLD}~/.config/hypr/hyprland.conf${NC}"
echo -e " Whatsie autostart nativo configurado: ${BOLD}sleep 2 && whatsie${NC}"
echo -e "${CYAN}------------------------------------------------------------${NC}"
echo -e "\n${BOLD}📋 Pasos recomendados:${NC}"
echo "   1. Si aún no usas Zsh como shell por defecto, ejecuta: chsh -s \$(which zsh)"
echo "   2. Recarga Hyprland o inicia una nueva sesión para aplicar los cambios."
echo ""
