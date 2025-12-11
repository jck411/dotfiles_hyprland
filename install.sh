#!/bin/bash

# Dotfiles Installation Script
# Creates symlinks from ~/.config to this repo

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories to symlink (relative to .config)
CONFIG_DIRS=(
    "hypr"
    "waybar"
    "foot"
    "rofi"
    "mako"
    "gtk-3.0"
    "gtk-4.0"
    "scripts"
)

# Files in home directory
HOME_FILES=(
    ".bashrc"
    ".zshrc"
)

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║     EndeavourOS Dotfiles Installer     ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

backup_existing() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        mkdir -p "$BACKUP_DIR"
        echo -e "${YELLOW}Backing up:${NC} $target -> $BACKUP_DIR/"
        mv "$target" "$BACKUP_DIR/"
    elif [ -L "$target" ]; then
        echo -e "${YELLOW}Removing existing symlink:${NC} $target"
        rm "$target"
    fi
}

create_symlink() {
    local source="$1"
    local target="$2"
    
    if [ ! -e "$source" ]; then
        echo -e "${RED}Source not found:${NC} $source"
        return 1
    fi
    
    backup_existing "$target"
    
    ln -s "$source" "$target"
    echo -e "${GREEN}Linked:${NC} $target -> $source"
}

install_config_dir() {
    local dir="$1"
    local source="$DOTFILES_DIR/config/$dir"
    local target="$CONFIG_DIR/$dir"
    
    create_symlink "$source" "$target"
}

install_home_file() {
    local file="$1"
    local source="$DOTFILES_DIR/shell/$file"
    local target="$HOME/$file"
    
    create_symlink "$source" "$target"
}

install_all() {
    print_header
    
    echo -e "${BLUE}Installing config directories...${NC}"
    for dir in "${CONFIG_DIRS[@]}"; do
        install_config_dir "$dir"
    done
    
    echo ""
    echo -e "${BLUE}Installing shell configs...${NC}"
    for file in "${HOME_FILES[@]}"; do
        install_home_file "$file"
    done
    
    echo ""
    echo -e "${GREEN}✓ Installation complete!${NC}"
    
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}Backups saved to:${NC} $BACKUP_DIR"
    fi
}

install_single() {
    local component="$1"
    
    case "$component" in
        hypr|waybar|foot|rofi|mako|gtk-3.0|gtk-4.0|scripts)
            install_config_dir "$component"
            ;;
        bashrc|.bashrc)
            install_home_file ".bashrc"
            ;;
        zshrc|.zshrc)
            install_home_file ".zshrc"
            ;;
        shell)
            install_home_file ".bashrc"
            install_home_file ".zshrc"
            ;;
        *)
            echo -e "${RED}Unknown component:${NC} $component"
            echo "Available: hypr, waybar, foot, rofi, mako, gtk-3.0, gtk-4.0, scripts, shell"
            exit 1
            ;;
    esac
}

backup_only() {
    print_header
    echo -e "${BLUE}Creating backups only (no symlinks)...${NC}"
    
    mkdir -p "$BACKUP_DIR"
    
    for dir in "${CONFIG_DIRS[@]}"; do
        local target="$CONFIG_DIR/$dir"
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            echo -e "${YELLOW}Backing up:${NC} $target"
            cp -r "$target" "$BACKUP_DIR/"
        fi
    done
    
    for file in "${HOME_FILES[@]}"; do
        local target="$HOME/$file"
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            echo -e "${YELLOW}Backing up:${NC} $target"
            cp "$target" "$BACKUP_DIR/"
        fi
    done
    
    echo -e "${GREEN}✓ Backups saved to:${NC} $BACKUP_DIR"
}

show_help() {
    echo "Usage: ./install.sh [OPTIONS] [COMPONENT]"
    echo ""
    echo "Options:"
    echo "  --backup-only    Only backup existing configs, don't symlink"
    echo "  --help           Show this help message"
    echo ""
    echo "Components:"
    echo "  hypr, waybar, foot, rofi, mako, gtk-3.0, gtk-4.0, scripts, shell"
    echo ""
    echo "Examples:"
    echo "  ./install.sh              # Install everything"
    echo "  ./install.sh hypr         # Install only Hyprland config"
    echo "  ./install.sh --backup-only"
}

# Main
case "${1:-}" in
    --help|-h)
        show_help
        ;;
    --backup-only)
        backup_only
        ;;
    "")
        install_all
        ;;
    *)
        install_single "$1"
        ;;
esac
