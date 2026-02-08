#!/bin/bash

# Package Sync Script
# Compares declared package lists against what's actually installed.
# Does NOT install or remove anything — shows you what's missing/extra.

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$DOTFILES_DIR/packages"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║       Package Sync Manager             ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Parse a package list file: strip comments, blank lines, AUR markers
parse_package_list() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: $file not found${NC}" >&2
        return 1
    fi
    # Remove comments (inline and full-line), trim whitespace, skip blanks
    sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//' "$file" | grep -v '^$'
}

# Get combined package list (base + host)
get_declared_packages() {
    local host="$1"
    local base_file="$PACKAGES_DIR/base.txt"
    local host_file="$PACKAGES_DIR/${host}.txt"

    if [ ! -f "$base_file" ]; then
        echo -e "${RED}Error: $base_file not found${NC}" >&2
        return 1
    fi

    parse_package_list "$base_file"

    if [ -n "$host" ] && [ -f "$host_file" ]; then
        parse_package_list "$host_file"
    fi
}

# Detect current host from symlink
detect_host() {
    local host_link="$DOTFILES_DIR/config/hypr/host.conf"
    if [ -L "$host_link" ]; then
        local target
        target=$(readlink "$host_link")
        # Extract host name from "hosts/foo.conf"
        basename "$target" .conf
    else
        echo "unknown"
    fi
}

# List available hosts
list_hosts() {
    echo -e "${BOLD}${CYAN}Available host profiles:${NC}"
    for file in "$PACKAGES_DIR"/*.txt; do
        [ -f "$file" ] || continue
        local name
        name=$(basename "$file" .txt)
        if [ "$name" = "base" ]; then
            echo -e "  ${GREEN}base${NC} (always included)"
        else
            echo -e "  ${BLUE}$name${NC}"
        fi
    done
}

# Show diff between declared and installed
check_packages() {
    local host="$1"

    print_header

    if [ -z "$host" ]; then
        host=$(detect_host)
    fi

    echo -e "${BOLD}Host profile:${NC} $host"

    local host_file="$PACKAGES_DIR/${host}.txt"
    if [ "$host" != "base" ] && [ "$host" != "unknown" ] && [ ! -f "$host_file" ]; then
        echo -e "${YELLOW}Warning: No package list for host '$host' — using base only${NC}"
    fi
    echo ""

    # Get declared packages (sorted, unique)
    local declared
    declared=$(get_declared_packages "$host" | sort -u)

    # Get installed packages
    local installed
    installed=$(pacman -Qqe | sort -u)

    # Missing: declared but not installed
    local missing
    missing=$(comm -23 <(echo "$declared") <(echo "$installed"))

    # Extra: installed but not declared
    local extra
    extra=$(comm -13 <(echo "$declared") <(echo "$installed"))

    # Present: in both
    local present
    present=$(comm -12 <(echo "$declared") <(echo "$installed"))

    local total_declared
    total_declared=$(echo "$declared" | wc -l)
    local total_present
    total_present=$(echo "$present" | grep -c . || echo 0)

    echo -e "${BOLD}${CYAN}=== Package Status ===${NC}"
    echo -e "  Declared: $total_declared  |  Installed: $(echo "$installed" | wc -l)  |  Matched: $total_present"
    echo ""

    if [ -n "$missing" ]; then
        local missing_count
        missing_count=$(echo "$missing" | wc -l)
        echo -e "${BOLD}${RED}=== Missing Packages ($missing_count) ===${NC}"
        echo -e "${YELLOW}These are declared in your lists but not installed:${NC}"
        echo "$missing" | while read -r pkg; do
            echo -e "  ${RED}✗${NC} $pkg"
        done
        echo ""
    else
        echo -e "${GREEN}✓ All declared packages are installed${NC}"
        echo ""
    fi

    if [ -n "$extra" ]; then
        local extra_count
        extra_count=$(echo "$extra" | wc -l)
        echo -e "${BOLD}${YELLOW}=== Extra Packages ($extra_count) ===${NC}"
        echo -e "${YELLOW}Installed but not in your package lists:${NC}"
        echo "$extra" | while read -r pkg; do
            echo -e "  ${YELLOW}?${NC} $pkg"
        done
        echo ""
    else
        echo -e "${GREEN}✓ No extra packages outside your lists${NC}"
        echo ""
    fi
}

# Generate install command for missing packages
install_missing() {
    local host="$1"

    if [ -z "$host" ]; then
        host=$(detect_host)
    fi

    local declared
    declared=$(get_declared_packages "$host" | sort -u)
    local installed
    installed=$(pacman -Qqe | sort -u)
    local missing
    missing=$(comm -23 <(echo "$declared") <(echo "$installed"))

    if [ -z "$missing" ]; then
        echo -e "${GREEN}✓ Nothing to install — all packages present${NC}"
        return 0
    fi

    # Split into repo and AUR packages
    local repo_pkgs=()
    local aur_pkgs=()

    while read -r pkg; do
        if pacman -Si "$pkg" &>/dev/null; then
            repo_pkgs+=("$pkg")
        else
            aur_pkgs+=("$pkg")
        fi
    done <<< "$missing"

    echo -e "${BOLD}${CYAN}=== Install Commands ===${NC}"
    if [ ${#repo_pkgs[@]} -gt 0 ]; then
        echo -e "${BLUE}Official repos:${NC}"
        echo -e "  sudo pacman -S ${repo_pkgs[*]}"
        echo ""
    fi
    if [ ${#aur_pkgs[@]} -gt 0 ]; then
        echo -e "${BLUE}AUR (via yay):${NC}"
        echo -e "  yay -S ${aur_pkgs[*]}"
        echo ""
    fi

    read -p "Run these commands now? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if [ ${#repo_pkgs[@]} -gt 0 ]; then
            echo -e "${BLUE}Installing repo packages...${NC}"
            sudo pacman -S --needed "${repo_pkgs[@]}"
        fi
        if [ ${#aur_pkgs[@]} -gt 0 ]; then
            echo -e "${BLUE}Installing AUR packages...${NC}"
            yay -S --needed "${aur_pkgs[@]}"
        fi
        echo -e "${GREEN}✓ Done${NC}"
    else
        echo -e "${YELLOW}Skipped. Copy the commands above to install manually.${NC}"
    fi
}

# Export currently installed packages to a new list
export_packages() {
    local output="$1"
    if [ -z "$output" ]; then
        output="$PACKAGES_DIR/exported-$(date +%Y%m%d).txt"
    fi

    echo "# Exported package list — $(date +%Y-%m-%d)" > "$output"
    echo "# Generated from: $(hostname)" >> "$output"
    echo "" >> "$output"
    pacman -Qqe | sort >> "$output"

    echo -e "${GREEN}✓ Exported $(pacman -Qqe | wc -l) packages to:${NC} $output"
}

show_help() {
    echo "Usage: ./packages.sh [COMMAND] [HOST]"
    echo ""
    echo "Commands:"
    echo "  status [HOST]    Compare declared vs installed packages (default)"
    echo "  install [HOST]   Show & optionally run install commands for missing packages"
    echo "  export [FILE]    Export currently installed packages to a file"
    echo "  hosts            List available host profiles"
    echo "  help             Show this help"
    echo ""
    echo "If HOST is omitted, it's auto-detected from config/hypr/host.conf symlink."
    echo ""
    echo "Examples:"
    echo "  ./packages.sh                          # Status for current host"
    echo "  ./packages.sh status dell-xps-13       # Status for specific host"
    echo "  ./packages.sh install                  # Install missing packages"
    echo "  ./packages.sh export                   # Dump installed to file"
    echo "  ./packages.sh hosts                    # List host profiles"
}

# Main
case "${1:-status}" in
    status)
        check_packages "$2"
        ;;
    install)
        install_missing "$2"
        ;;
    export)
        export_packages "$2"
        ;;
    hosts)
        list_hosts
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
