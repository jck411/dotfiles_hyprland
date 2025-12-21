#!/bin/bash

# Dotfiles Sync Script
# Detects orphaned configs, suggests new configs to track, and syncs everything

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
SHELL_DIR="$DOTFILES_DIR/shell"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configs to always ignore (app data, caches, sensitive, too large)
IGNORE_LIST=(
    # Large app data / caches
    "Antigravity"
    "BraveSoftware"
    "Code - Insiders"
    "Cursor"
    "Electron"
    "dconf"
    "go"
    "pulse"
    "rclone"
    "spicetify"
    "spotify"
    "yay"
    "inkscape"
    
    # Repo files
    ".git"
    ".github"
    ".gitignore"
    "README.md"
    
    # EndeavourOS system files
    "EOS-greeter.conf"
    "welcome.conf"
    "reflector-simple-free-params.txt"
    
    # Auto-generated / trivial
    "last_update_timestamp"
    "pavucontrol.ini"
    "mimeapps.list"
    "Mousepad"
    "xfce4"
    "shell_pilot"
    
    # Backup files
    "*.bak.*"
)

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║       Dotfiles Sync Manager            ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

is_ignored() {
    local name="$1"
    for ignore in "${IGNORE_LIST[@]}"; do
        if [[ "$name" == "$ignore" ]]; then
            return 0
        fi
    done
    return 1
}

# Check for orphaned configs (in repo but not symlinked)
check_orphaned() {
    echo -e "${BOLD}${CYAN}=== Orphaned Configs (in repo, not on system) ===${NC}"
    local found=0
    
    for item in "$DOTFILES_DIR/config/"*; do
        [ -e "$item" ] || continue
        local name=$(basename "$item")
        local target="$CONFIG_DIR/$name"
        
        if [ ! -e "$target" ]; then
            echo -e "  ${RED}✗${NC} $name - ${YELLOW}not on system${NC}"
            found=1
        elif [ ! -L "$target" ]; then
            echo -e "  ${YELLOW}⚠${NC} $name - ${YELLOW}exists but not symlinked${NC}"
            found=1
        fi
    done
    
    if [ $found -eq 0 ]; then
        echo -e "  ${GREEN}✓ All repo configs are properly symlinked${NC}"
    fi
    echo ""
}

# Check for untracked configs (on system but not in repo)
check_untracked() {
    echo -e "${BOLD}${CYAN}=== Untracked Configs (on system, not in repo) ===${NC}"
    local found=0
    
    for item in "$CONFIG_DIR/"*; do
        [ -e "$item" ] || continue
        local name=$(basename "$item")
        local repo_path="$DOTFILES_DIR/config/$name"
        
        # Skip if ignored
        is_ignored "$name" && continue
        
        # Skip if already a symlink pointing to our repo
        if [ -L "$item" ]; then
            local link_target=$(readlink -f "$item" 2>/dev/null || echo "")
            if [[ "$link_target" == "$DOTFILES_DIR"* ]]; then
                continue
            fi
        fi
        
        # Skip if already in repo
        [ -e "$repo_path" ] && continue
        
        # Get size
        local size=$(du -sh "$item" 2>/dev/null | cut -f1)
        echo -e "  ${YELLOW}?${NC} $name ${BLUE}($size)${NC}"
        found=1
    done
    
    if [ $found -eq 0 ]; then
        echo -e "  ${GREEN}✓ No new configs to track${NC}"
    fi
    echo ""
}

# Interactive add new config
add_config() {
    local name="$1"
    local source="$CONFIG_DIR/$name"
    local target="$DOTFILES_DIR/config/$name"
    
    if [ ! -e "$source" ]; then
        echo -e "${RED}Error: $source does not exist${NC}"
        return 1
    fi
    
    if [ -e "$target" ]; then
        echo -e "${YELLOW}Already in repo: $name${NC}"
        return 0
    fi
    
    # Move to repo
    echo -e "${BLUE}Moving $name to repo...${NC}"
    mv "$source" "$target"
    
    # Create symlink
    ln -s "$target" "$source"
    echo -e "${GREEN}✓ Added and symlinked: $name${NC}"
}

# Remove orphaned config from repo
remove_config() {
    local name="$1"
    local repo_path="$DOTFILES_DIR/config/$name"
    local system_path="$CONFIG_DIR/$name"
    
    if [ ! -e "$repo_path" ]; then
        echo -e "${RED}Error: $name not in repo${NC}"
        return 1
    fi
    
    # Remove symlink if it exists and points to our repo
    if [ -L "$system_path" ]; then
        local link_target=$(readlink -f "$system_path" 2>/dev/null || echo "")
        if [[ "$link_target" == "$DOTFILES_DIR"* ]]; then
            rm "$system_path"
            echo -e "${YELLOW}Removed symlink: $system_path${NC}"
        fi
    fi
    
    # Remove from repo
    rm -rf "$repo_path"
    echo -e "${GREEN}✓ Removed from repo: $name${NC}"
}

# Fix symlinks (for configs in repo but not symlinked)
fix_symlinks() {
    echo -e "${BOLD}${CYAN}=== Fixing Symlinks ===${NC}"
    local fixed=0
    
    for item in "$DOTFILES_DIR/config/"*; do
        [ -e "$item" ] || continue
        local name=$(basename "$item")
        local target="$CONFIG_DIR/$name"
        
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            # Backup and replace
            local backup="$target.bak.$(date +%Y%m%d-%H%M%S)"
            mv "$target" "$backup"
            ln -s "$item" "$target"
            echo -e "  ${GREEN}✓${NC} Fixed: $name (backup at $backup)"
            fixed=1
        elif [ ! -e "$target" ]; then
            ln -s "$item" "$target"
            echo -e "  ${GREEN}✓${NC} Created: $name"
            fixed=1
        fi
    done
    
    if [ $fixed -eq 0 ]; then
        echo -e "  ${GREEN}✓ All symlinks are correct${NC}"
    fi
    echo ""
}

# Interactive sync mode
interactive_sync() {
    print_header
    
    check_orphaned
    check_untracked
    
    echo -e "${BOLD}${CYAN}=== Actions ===${NC}"
    echo "  1) Fix all symlinks (link repo configs to system)"
    echo "  2) Add a config to repo"
    echo "  3) Remove a config from repo"
    echo "  4) Show ignore list"
    echo "  5) Exit"
    echo ""
    
    read -p "Choose action [1-5]: " choice
    
    case "$choice" in
        1)
            fix_symlinks
            ;;
        2)
            read -p "Config name to add: " config_name
            add_config "$config_name"
            ;;
        3)
            read -p "Config name to remove: " config_name
            remove_config "$config_name"
            ;;
        4)
            echo -e "${CYAN}Ignored configs:${NC}"
            printf '  %s\n' "${IGNORE_LIST[@]}"
            ;;
        5)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
}

# Status check (non-interactive)
status_check() {
    print_header
    check_orphaned
    check_untracked
    
    echo -e "${BOLD}${CYAN}=== Symlink Status ===${NC}"
    for item in "$DOTFILES_DIR/config/"*; do
        [ -e "$item" ] || continue
        local name=$(basename "$item")
        local target="$CONFIG_DIR/$name"
        
        if [ -L "$target" ]; then
            echo -e "  ${GREEN}✓${NC} $name"
        elif [ -e "$target" ]; then
            echo -e "  ${YELLOW}⚠${NC} $name (not symlinked)"
        else
            echo -e "  ${RED}✗${NC} $name (missing)"
        fi
    done
    echo ""
}

show_help() {
    echo "Usage: ./sync.sh [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  status      Show sync status (default)"
    echo "  fix         Fix all symlinks"
    echo "  add NAME    Add a config to the repo"
    echo "  remove NAME Remove a config from the repo"
    echo "  interactive Interactive menu"
    echo "  help        Show this help"
    echo ""
    echo "Examples:"
    echo "  ./sync.sh                    # Show status"
    echo "  ./sync.sh fix                # Fix all symlinks"
    echo "  ./sync.sh add cursor-flags.conf"
    echo "  ./sync.sh remove old-config"
}

# Main
case "${1:-status}" in
    status)
        status_check
        ;;
    fix)
        fix_symlinks
        ;;
    add)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Specify config name${NC}"
            exit 1
        fi
        add_config "$2"
        ;;
    remove)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Specify config name${NC}"
            exit 1
        fi
        remove_config "$2"
        ;;
    interactive|-i)
        interactive_sync
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac
