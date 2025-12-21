#!/bin/bash
# Generic tarball updater - auto-detects and installs ANY tarball in ~/Downloads
# 1. Updates registered apps from profile.json
# 2. Auto-registers and installs NEW tarballs with sensible defaults
#
# Usage: update-tarballs.sh [--silent]

set -e

DOWNLOAD_DIR="$HOME/Downloads"
PROFILE_PATH="$HOME/GoogleDrive/host_profiles/xps13/profile.json"

# Silent mode for use in other scripts
SILENT=false
[[ "$1" == "--silent" ]] && SILENT=true

# Colors
if [[ "$SILENT" == false ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' RED='' CYAN='' BOLD='' NC=''
fi

log() { [[ "$SILENT" == false ]] && echo -e "$1"; }

# Check for jq
if ! command -v jq &>/dev/null; then
    log "${RED}Error: jq is required but not installed${NC}"
    exit 1
fi

# Ensure profile exists with tarball_packages section
if [[ ! -f "$PROFILE_PATH" ]]; then
    log "${YELLOW}Profile not found at $PROFILE_PATH${NC}"
    exit 1
fi

# Get tarball packages from profile (may be empty)
TARBALL_PACKAGES=$(jq -r '.software.tarball_packages // {}' "$PROFILE_PATH" 2>/dev/null)

# Track results
UPDATED=()
SKIPPED=()
REGISTERED=()

# =============================================================================
# PART 1: Update registered tarball packages
# =============================================================================

for APP_NAME in $(echo "$TARBALL_PACKAGES" | jq -r 'keys[]' 2>/dev/null); do
    APP_CONFIG=$(echo "$TARBALL_PACKAGES" | jq -r ".\"$APP_NAME\"")
    
    PATTERN=$(echo "$APP_CONFIG" | jq -r '.tarball_pattern // empty')
    INSTALL_DIR=$(echo "$APP_CONFIG" | jq -r '.install_dir // empty' | sed "s|~|$HOME|g")
    BINARY_NAME=$(echo "$APP_CONFIG" | jq -r '.binary_name // empty')
    SYMLINK=$(echo "$APP_CONFIG" | jq -r '.symlink // empty')
    
    if [[ -z "$PATTERN" || -z "$INSTALL_DIR" ]]; then
        continue
    fi
    
    TARBALL=$(find "$DOWNLOAD_DIR" -maxdepth 1 -name "$PATTERN" -type f 2>/dev/null | head -1)
    
    if [[ -z "$TARBALL" ]]; then
        SKIPPED+=("$APP_NAME")
        continue
    fi
    
    log "${CYAN}=== Updating $APP_NAME ===${NC}"
    log "Found: $(basename "$TARBALL")"
    
    # Remove old installation
    [[ -d "$INSTALL_DIR" ]] && rm -rf "$INSTALL_DIR"
    
    # Extract
    PARENT_DIR=$(dirname "$INSTALL_DIR")
    mkdir -p "$PARENT_DIR"
    tar -xzf "$TARBALL" -C "$PARENT_DIR"
    
    # Create symlink if specified
    if [[ -n "$SYMLINK" && -n "$BINARY_NAME" ]]; then
        BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"
        [[ -f "$BINARY_PATH" ]] && sudo ln -sf "$BINARY_PATH" "$SYMLINK"
    fi
    
    rm -f "$TARBALL"
    log "${GREEN}✓ $APP_NAME updated${NC}"
    UPDATED+=("$APP_NAME")
done

# =============================================================================
# PART 2: Auto-detect and register NEW tarballs
# =============================================================================

# Find all tarballs in Downloads
ALL_TARBALLS=$(find "$DOWNLOAD_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.tar.xz" -o -name "*.tar.bz2" -o -name "*.tgz" \) 2>/dev/null)

for TARBALL in $ALL_TARBALLS; do
    [[ -z "$TARBALL" ]] && continue
    
    FILENAME=$(basename "$TARBALL")
    
    # Extract app name from filename (remove version numbers and extension)
    # Examples: Antigravity-1.2.3.tar.gz -> antigravity, Obsidian.tar.gz -> obsidian
    APP_NAME=$(echo "$FILENAME" | sed -E 's/[-_.]?[0-9]+(\.[0-9]+)*//g' | sed -E 's/\.(tar\.(gz|xz|bz2)|tgz)$//' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z')
    
    [[ -z "$APP_NAME" ]] && continue
    
    # Check if already registered
    if echo "$TARBALL_PACKAGES" | jq -e ".\"$APP_NAME\"" &>/dev/null; then
        continue  # Already handled in Part 1
    fi
    
    log "${CYAN}=== New tarball detected: $FILENAME ===${NC}"
    log "Auto-registering as: ${BOLD}$APP_NAME${NC}"
    
    # Derive defaults from filename
    # Get the actual directory name from inside the tarball
    TARBALL_TOP_DIR=$(tar -tzf "$TARBALL" 2>/dev/null | head -1 | cut -d'/' -f1)
    
    if [[ -z "$TARBALL_TOP_DIR" ]]; then
        log "${YELLOW}⚠ Could not determine tarball structure - skipping${NC}"
        continue
    fi
    
    INSTALL_DIR="$HOME/$TARBALL_TOP_DIR"
    PATTERN="${TARBALL_TOP_DIR}*.tar.gz"
    
    # Try to find a binary (look for executable with same name as app)
    BINARY_NAME=""
    SYMLINK=""
    
    # Common binary name patterns
    for TRY_BIN in "$APP_NAME" "${TARBALL_TOP_DIR,,}" "$TARBALL_TOP_DIR"; do
        if tar -tzf "$TARBALL" 2>/dev/null | grep -qE "^[^/]+/$TRY_BIN$"; then
            BINARY_NAME="$TRY_BIN"
            SYMLINK="/usr/bin/$APP_NAME"
            break
        fi
    done
    
    # Extract the tarball
    log "Extracting to $HOME..."
    [[ -d "$INSTALL_DIR" ]] && rm -rf "$INSTALL_DIR"
    tar -xzf "$TARBALL" -C "$HOME/"
    
    # Create symlink if we found a binary
    if [[ -n "$BINARY_NAME" && -f "$INSTALL_DIR/$BINARY_NAME" ]]; then
        log "Creating symlink: $SYMLINK -> $INSTALL_DIR/$BINARY_NAME"
        sudo ln -sf "$INSTALL_DIR/$BINARY_NAME" "$SYMLINK"
    fi
    
    # Register in profile.json
    log "Registering in profile.json..."
    
    NEW_ENTRY=$(jq -n \
        --arg desc "Auto-registered tarball app" \
        --arg pattern "$PATTERN" \
        --arg install_dir "~/$TARBALL_TOP_DIR" \
        --arg binary "$BINARY_NAME" \
        --arg symlink "$SYMLINK" \
        '{
            description: $desc,
            tarball_pattern: $pattern,
            install_dir: $install_dir,
            binary_name: $binary,
            symlink: $symlink
        }')
    
    # Update profile.json
    jq --arg name "$APP_NAME" --argjson entry "$NEW_ENTRY" \
        '.software.tarball_packages[$name] = $entry' \
        "$PROFILE_PATH" > "$PROFILE_PATH.tmp" && mv "$PROFILE_PATH.tmp" "$PROFILE_PATH"
    
    # Clean up tarball
    rm -f "$TARBALL"
    
    log "${GREEN}✓ $APP_NAME installed and registered${NC}"
    REGISTERED+=("$APP_NAME")
done

# =============================================================================
# Summary
# =============================================================================

echo ""
log "${BOLD}=== Tarball Update Summary ===${NC}"

if [[ ${#UPDATED[@]} -gt 0 ]]; then
    log "${GREEN}Updated: ${UPDATED[*]}${NC}"
fi

if [[ ${#REGISTERED[@]} -gt 0 ]]; then
    log "${GREEN}New installs: ${REGISTERED[*]}${NC}"
fi

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    log "${YELLOW}No updates: ${SKIPPED[*]}${NC}"
fi

if [[ ${#UPDATED[@]} -eq 0 && ${#REGISTERED[@]} -eq 0 && ${#SKIPPED[@]} -eq 0 ]]; then
    log "No tarballs found in $DOWNLOAD_DIR"
fi
