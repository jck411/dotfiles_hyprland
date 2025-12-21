#!/bin/bash
# Generic tarball updater - reads from profile.json
# Checks ~/Downloads for tarballs matching registered apps
# Cleans old install, extracts, creates symlink, removes tarball
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
    NC='\033[0m'
else
    GREEN='' YELLOW='' RED='' CYAN='' NC=''
fi

log() { [[ "$SILENT" == false ]] && echo -e "$1"; }

# Check for jq
if ! command -v jq &>/dev/null; then
    log "${RED}Error: jq is required but not installed${NC}"
    exit 1
fi

# Check profile exists
if [[ ! -f "$PROFILE_PATH" ]]; then
    log "${YELLOW}Profile not found at $PROFILE_PATH - skipping tarball updates${NC}"
    exit 0
fi

# Get tarball packages from profile
TARBALL_PACKAGES=$(jq -r '.software.tarball_packages // empty' "$PROFILE_PATH" 2>/dev/null)

if [[ -z "$TARBALL_PACKAGES" || "$TARBALL_PACKAGES" == "null" ]]; then
    log "${YELLOW}No tarball packages registered in profile${NC}"
    exit 0
fi

# Track what we updated
UPDATED=()
SKIPPED=()

# Process each registered tarball package
for APP_NAME in $(echo "$TARBALL_PACKAGES" | jq -r 'keys[]'); do
    APP_CONFIG=$(echo "$TARBALL_PACKAGES" | jq -r ".[\"$APP_NAME\"]")
    
    # Get config values
    PATTERN=$(echo "$APP_CONFIG" | jq -r '.tarball_pattern // empty')
    INSTALL_DIR=$(echo "$APP_CONFIG" | jq -r '.install_dir // empty' | sed "s|~|$HOME|g")
    BINARY_NAME=$(echo "$APP_CONFIG" | jq -r '.binary_name // empty')
    SYMLINK=$(echo "$APP_CONFIG" | jq -r '.symlink // empty')
    
    # Skip if missing required fields
    if [[ -z "$PATTERN" || -z "$INSTALL_DIR" ]]; then
        log "${YELLOW}⚠ $APP_NAME: missing tarball_pattern or install_dir - skipping${NC}"
        continue
    fi
    
    # Find matching tarball in Downloads
    TARBALL=$(find "$DOWNLOAD_DIR" -maxdepth 1 -name "$PATTERN" -type f 2>/dev/null | head -1)
    
    if [[ -z "$TARBALL" ]]; then
        SKIPPED+=("$APP_NAME")
        continue
    fi
    
    log "${CYAN}=== Updating $APP_NAME ===${NC}"
    log "Found: $(basename "$TARBALL")"
    
    # Remove old installation
    if [[ -d "$INSTALL_DIR" ]]; then
        log "Removing old installation at $INSTALL_DIR..."
        rm -rf "$INSTALL_DIR"
    fi
    
    # Get parent directory for extraction
    PARENT_DIR=$(dirname "$INSTALL_DIR")
    mkdir -p "$PARENT_DIR"
    
    # Extract tarball
    log "Extracting to $PARENT_DIR..."
    tar -xzf "$TARBALL" -C "$PARENT_DIR"
    
    if [[ $? -ne 0 ]]; then
        log "${RED}✗ Extraction failed for $APP_NAME${NC}"
        continue
    fi
    
    # Create symlink if specified
    if [[ -n "$SYMLINK" && -n "$BINARY_NAME" ]]; then
        BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"
        if [[ -f "$BINARY_PATH" ]]; then
            log "Creating symlink: $SYMLINK -> $BINARY_PATH"
            sudo ln -sf "$BINARY_PATH" "$SYMLINK"
        else
            log "${YELLOW}⚠ Binary not found at $BINARY_PATH${NC}"
        fi
    fi
    
    # Clean up tarball
    rm -f "$TARBALL"
    log "${GREEN}✓ $APP_NAME updated successfully${NC}"
    
    UPDATED+=("$APP_NAME")
done

# Summary
echo ""
if [[ ${#UPDATED[@]} -gt 0 ]]; then
    log "${GREEN}Updated: ${UPDATED[*]}${NC}"
fi

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    log "${YELLOW}No updates found for: ${SKIPPED[*]}${NC}"
fi

if [[ ${#UPDATED[@]} -eq 0 && ${#SKIPPED[@]} -eq 0 ]]; then
    log "${YELLOW}No tarball packages registered${NC}"
fi
