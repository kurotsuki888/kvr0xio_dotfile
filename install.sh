#!/usr/bin/env bash

# Installation script for kvr0xio_dotfile
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Instalando configuraciones desde kvr0xio_dotfile..."

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

echo "✨ ¡Configuraciones instaladas con éxito!"
