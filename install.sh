#!/usr/bin/env bash

# Install Asimov as a launchd daemon.
#
# @author  Steve Grunwell (Original Author)
# @author  Tobias Hochguertel <tobias.hochguertel@googlemail.com> (Fork Maintainer)
# @license MIT

set -e

DIR="$(cd "$(dirname "$0")" || return; pwd -P)"
PLIST="com.stevegrunwell.asimov.plist"
PLIST_ZSH="com.tobiashochguertel.asimov-zsh.plist"

# Installation directories
INSTALL_BIN="/usr/local/bin"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Parse arguments
USE_ZSH=false
UNINSTALL=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --zsh)
            USE_ZSH=true
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --zsh       Install the optimized ZSH version (asimov-zsh)"
            echo "  --uninstall Remove asimov installation"
            echo "  -h          Show this help message"
            echo ""
            echo "The ZSH version requires: fd, zsh"
            echo "Install fd via: brew install fd"
            echo ""
            echo "Installation locations:"
            echo "  Binary:  ${INSTALL_BIN}/asimov"
            echo "  Daemon:  ${LAUNCH_AGENTS_DIR}/<plist>"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Uninstall function
uninstall() {
    echo -e "${CYAN}Uninstalling asimov...${NC}"
    
    # Unload daemons
    if launchctl list 2>/dev/null | grep -q com.tobiashochguertel.asimov-zsh; then
        echo -e "${CYAN}Unloading ZSH daemon...${NC}"
        launchctl unload "${LAUNCH_AGENTS_DIR}/${PLIST_ZSH}" 2>/dev/null || true
    fi
    
    if launchctl list 2>/dev/null | grep -q com.stevegrunwell.asimov; then
        echo -e "${CYAN}Unloading bash daemon...${NC}"
        launchctl unload "${LAUNCH_AGENTS_DIR}/${PLIST}" 2>/dev/null || true
    fi
    
    # Remove plist files
    rm -f "${LAUNCH_AGENTS_DIR}/${PLIST}" 2>/dev/null || true
    rm -f "${LAUNCH_AGENTS_DIR}/${PLIST_ZSH}" 2>/dev/null || true
    
    # Remove binary (may need sudo)
    if [[ -e "${INSTALL_BIN}/asimov" ]]; then
        echo -e "${CYAN}Removing ${INSTALL_BIN}/asimov...${NC}"
        rm -f "${INSTALL_BIN}/asimov" 2>/dev/null || sudo rm -f "${INSTALL_BIN}/asimov"
    fi
    
    echo -e "${GREEN}✓ Asimov has been uninstalled${NC}"
    exit 0
}

if $UNINSTALL; then
    uninstall
fi

# Ensure directories exist
mkdir -p "${INSTALL_BIN}" 2>/dev/null || sudo mkdir -p "${INSTALL_BIN}"
mkdir -p "${LAUNCH_AGENTS_DIR}"

if $USE_ZSH; then
    echo -e "${CYAN}Installing asimov-zsh (optimized ZSH version)...${NC}"
    echo ""
    
    # Check for fd dependency
    if ! command -v fd &>/dev/null; then
        echo -e "${RED}Error: 'fd' is required for asimov-zsh but not installed.${NC}"
        echo "Install it via: brew install fd"
        exit 1
    fi
    echo -e "${GREEN}✓ fd is installed${NC}"

    # Verify that Asimov-ZSH is executable
    chmod +x "${DIR}/asimov-zsh"

    # Copy Asimov-ZSH to /usr/local/bin (not symlink for production)
    echo -e "${CYAN}Installing asimov-zsh to ${INSTALL_BIN}/asimov...${NC}"
    if [[ -w "${INSTALL_BIN}" ]]; then
        cp -f "${DIR}/asimov-zsh" "${INSTALL_BIN}/asimov"
    else
        sudo cp -f "${DIR}/asimov-zsh" "${INSTALL_BIN}/asimov"
    fi
    chmod +x "${INSTALL_BIN}/asimov"
    echo -e "${GREEN}✓ Installed to ${INSTALL_BIN}/asimov${NC}"

    # Unload any existing daemons
    if launchctl list 2>/dev/null | grep -q com.stevegrunwell.asimov; then
        echo -e "${CYAN}Unloading original bash daemon...${NC}"
        launchctl unload "${LAUNCH_AGENTS_DIR}/${PLIST}" 2>/dev/null || true
        rm -f "${LAUNCH_AGENTS_DIR}/${PLIST}" 2>/dev/null || true
    fi

    if launchctl list 2>/dev/null | grep -q com.tobiashochguertel.asimov-zsh; then
        echo -e "${CYAN}Unloading existing ZSH daemon...${NC}"
        launchctl unload "${LAUNCH_AGENTS_DIR}/${PLIST_ZSH}" 2>/dev/null || true
    fi

    # Copy plist to LaunchAgents (production location)
    echo -e "${CYAN}Installing daemon to ${LAUNCH_AGENTS_DIR}/${PLIST_ZSH}...${NC}"
    cp -f "${DIR}/${PLIST_ZSH}" "${LAUNCH_AGENTS_DIR}/${PLIST_ZSH}"
    echo -e "${GREEN}✓ Daemon plist installed${NC}"

    # Load the daemon
    launchctl load "${LAUNCH_AGENTS_DIR}/${PLIST_ZSH}"
    echo -e "${GREEN}✓ Daemon loaded (will run daily)${NC}"

    # Run Asimov-ZSH for the first time
    echo ""
    echo -e "${CYAN}Running asimov for the first time...${NC}"
    echo -e "${YELLOW}(This may take a while for large home directories)${NC}"
    echo ""
    "${INSTALL_BIN}/asimov"
    
else
    echo -e "${CYAN}Installing asimov (original bash version)...${NC}"
    echo ""

    # Verify that Asimov is executable
    chmod +x "${DIR}/asimov"

    # Copy Asimov to /usr/local/bin (not symlink for production)
    echo -e "${CYAN}Installing asimov to ${INSTALL_BIN}/asimov...${NC}"
    if [[ -w "${INSTALL_BIN}" ]]; then
        cp -f "${DIR}/asimov" "${INSTALL_BIN}/asimov"
    else
        sudo cp -f "${DIR}/asimov" "${INSTALL_BIN}/asimov"
    fi
    chmod +x "${INSTALL_BIN}/asimov"
    echo -e "${GREEN}✓ Installed to ${INSTALL_BIN}/asimov${NC}"

    # Unload any existing daemons
    if launchctl list 2>/dev/null | grep -q com.tobiashochguertel.asimov-zsh; then
        echo -e "${CYAN}Unloading ZSH daemon...${NC}"
        launchctl unload "${LAUNCH_AGENTS_DIR}/${PLIST_ZSH}" 2>/dev/null || true
        rm -f "${LAUNCH_AGENTS_DIR}/${PLIST_ZSH}" 2>/dev/null || true
    fi

    if launchctl list 2>/dev/null | grep -q com.stevegrunwell.asimov; then
        echo -e "${CYAN}Unloading existing bash daemon...${NC}"
        launchctl unload "${LAUNCH_AGENTS_DIR}/${PLIST}" 2>/dev/null || true
    fi

    # Copy plist to LaunchAgents (production location)
    echo -e "${CYAN}Installing daemon to ${LAUNCH_AGENTS_DIR}/${PLIST}...${NC}"
    cp -f "${DIR}/${PLIST}" "${LAUNCH_AGENTS_DIR}/${PLIST}"
    echo -e "${GREEN}✓ Daemon plist installed${NC}"

    # Load the daemon
    launchctl load "${LAUNCH_AGENTS_DIR}/${PLIST}"
    echo -e "${GREEN}✓ Daemon loaded (will run daily)${NC}"

    # Run Asimov for the first time
    echo ""
    echo -e "${CYAN}Running asimov for the first time...${NC}"
    echo ""
    "${INSTALL_BIN}/asimov"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Installation Complete!                        ║${NC}"
echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║  Binary installed to:  ${INSTALL_BIN}/asimov${NC}"
echo -e "${GREEN}║  Daemon plist at:      ${LAUNCH_AGENTS_DIR}/...${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║  The daemon will run automatically every 24 hours.         ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}║  Commands:                                                 ║${NC}"
echo -e "${GREEN}║    asimov                    Run manually                  ║${NC}"
echo -e "${GREEN}║    ./install.sh --uninstall  Remove asimov                 ║${NC}"
echo -e "${GREEN}║                                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
