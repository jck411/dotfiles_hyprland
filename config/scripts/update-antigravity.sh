#!/bin/bash
# Update Antigravity from downloaded tarball
# Fully automatic - no prompts
# Usage: update-antigravity.sh [--silent]

DOWNLOAD_DIR="$HOME/Downloads"
TARBALL="$DOWNLOAD_DIR/Antigravity.tar.gz"
INSTALL_DIR="$HOME/Antigravity"
SYMLINK="/usr/bin/antigravity"

# Silent mode for use in other scripts
SILENT=false
[[ "$1" == "--silent" ]] && SILENT=true

# Colors (only if not silent)
if [[ "$SILENT" == false ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' RED='' NC=''
fi

log() {
    [[ "$SILENT" == false ]] && echo -e "$1"
}

# Check if tarball exists
if [[ ! -f "$TARBALL" ]]; then
    log "${YELLOW}No Antigravity tarball found - skipping${NC}"
    exit 0
fi

log "${GREEN}Found Antigravity update: $TARBALL${NC}"

# Remove old installation
if [[ -d "$INSTALL_DIR" ]]; then
    log "Removing old installation..."
    rm -rf "$INSTALL_DIR"
fi

# Extract
log "Extracting..."
tar -xzf "$TARBALL" -C "$HOME/"

if [[ $? -ne 0 ]]; then
    log "${RED}Extraction failed!${NC}"
    exit 1
fi

# Update symlink
log "Updating symlink..."
sudo ln -sf "$INSTALL_DIR/antigravity" "$SYMLINK"

# Clean up tarball
rm -f "$TARBALL"

log "${GREEN}✓ Antigravity updated and tarball cleaned up${NC}"
