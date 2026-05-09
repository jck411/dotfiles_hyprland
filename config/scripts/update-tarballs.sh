#!/bin/bash
# Standalone tarball updater - installs/updates any tarball found in ~/Downloads
# App registry stored locally in ~/.config/tarball-apps.json (no external dependencies)
#
# Usage: update-tarballs.sh

set -e

DOWNLOAD_DIR="$HOME/Downloads"
CONFIG_FILE="$HOME/.config/tarball-apps.json"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "$1"; }

# Check for jq
if ! command -v jq &>/dev/null; then
    log "${RED}Error: jq is required but not installed${NC}" >&2
    exit 1
fi

# Initialize local config if missing
[[ ! -f "$CONFIG_FILE" ]] && echo '{"tarball_packages":{}}' > "$CONFIG_FILE"

# Find all tarballs in Downloads
mapfile -t TARBALLS < <(find "$DOWNLOAD_DIR" -maxdepth 1 -type f \
    \( -name "*.tar.gz" -o -name "*.tar.xz" -o -name "*.tar.bz2" -o -name "*.tgz" \) \
    2>/dev/null | sort)

if [[ ${#TARBALLS[@]} -eq 0 ]]; then
    log "No tarballs found in $DOWNLOAD_DIR"
    exit 0
fi

# Cache sudo credentials once upfront — no mid-script prompts
sudo -v

UPDATED=()
INSTALLED=()

for TARBALL in "${TARBALLS[@]}"; do
    FILENAME=$(basename "$TARBALL")

    # Derive app name: strip version numbers + extension, lowercase letters only
    APP_NAME=$(echo "$FILENAME" \
        | sed -E 's/[-_.]?[0-9]+(\.[0-9]+)*[-_.]?//g' \
        | sed -E 's/\.(tar\.(gz|xz|bz2)|tgz)$//' \
        | tr '[:upper:]' '[:lower:]' \
        | tr -cd 'a-z')
    [[ -z "$APP_NAME" ]] && APP_NAME=$(echo "$FILENAME" \
        | sed -E 's/\.(tar\.(gz|xz|bz2)|tgz)$//' \
        | tr '[:upper:]' '[:lower:]')

    log "${CYAN}=== Processing: $FILENAME ===${NC}"

    # Get top-level directory from inside the tarball
    TOP_DIR=$(tar -tf "$TARBALL" 2>/dev/null | head -1 | cut -d'/' -f1)
    if [[ -z "$TOP_DIR" ]]; then
        log "${YELLOW}⚠ Could not read tarball structure — skipping${NC}"
        continue
    fi

    # Look up existing registration
    REGISTERED=$(jq -r ".tarball_packages[\"$APP_NAME\"] // empty" "$CONFIG_FILE")

    if [[ -n "$REGISTERED" ]]; then
        INSTALL_DIR=$(echo "$REGISTERED" | jq -r '.install_dir' | sed "s|~|$HOME|g")
        BINARY_NAME=$(echo "$REGISTERED" | jq -r '.binary_name // empty')
        SYMLINK=$(echo "$REGISTERED"    | jq -r '.symlink // empty')
    else
        # New app: default install to /opt/<TopDir>
        INSTALL_DIR="/opt/$TOP_DIR"
        BINARY_NAME=""
        SYMLINK=""

        # Look for a binary matching the app name inside the tarball
        for TRY_BIN in "$APP_NAME" "${TOP_DIR,,}" "$TOP_DIR"; do
            if tar -tf "$TARBALL" 2>/dev/null | grep -qE "^[^/]+/$TRY_BIN$"; then
                BINARY_NAME="$TRY_BIN"
                SYMLINK="/usr/bin/$APP_NAME"
                break
            fi
        done
    fi

    # Remove old installation
    [[ -d "$INSTALL_DIR" ]] && sudo rm -rf "$INSTALL_DIR"

    # Extract to parent directory
    PARENT_DIR=$(dirname "$INSTALL_DIR")
    sudo mkdir -p "$PARENT_DIR"
    sudo tar -xf "$TARBALL" -C "$PARENT_DIR"

    # Create /usr/bin symlink if a binary was found
    if [[ -n "$SYMLINK" && -n "$BINARY_NAME" && -f "$INSTALL_DIR/$BINARY_NAME" ]]; then
        sudo ln -sf "$INSTALL_DIR/$BINARY_NAME" "$SYMLINK"
        log "  Linked: $SYMLINK → $INSTALL_DIR/$BINARY_NAME"
    fi

    # Save/update registration in local config
    INSTALL_DIR_STORED=$(echo "$INSTALL_DIR" | sed "s|$HOME|~|g")
    jq --arg name        "$APP_NAME" \
       --arg install_dir "$INSTALL_DIR_STORED" \
       --arg binary      "$BINARY_NAME" \
       --arg symlink     "$SYMLINK" \
       --arg pattern     "${TOP_DIR}*.tar.gz" \
       '.tarball_packages[$name] = {
           install_dir:     $install_dir,
           binary_name:     $binary,
           symlink:         $symlink,
           tarball_pattern: $pattern
       }' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    # Remove tarball after successful install
    rm -f "$TARBALL"

    if [[ -n "$REGISTERED" ]]; then
        log "${GREEN}✓ $APP_NAME updated${NC}"
        UPDATED+=("$APP_NAME")
    else
        log "${GREEN}✓ $APP_NAME installed${NC}"
        INSTALLED+=("$APP_NAME")
    fi
done

echo ""
echo -e "${BOLD}=== Tarball Summary ===${NC}"
[[ ${#UPDATED[@]}   -gt 0 ]] && log "${GREEN}Updated:   ${UPDATED[*]}${NC}"
[[ ${#INSTALLED[@]} -gt 0 ]] && log "${GREEN}Installed: ${INSTALLED[*]}${NC}"
