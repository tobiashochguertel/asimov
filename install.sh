#!/usr/bin/env bash

# Install Asimov as a launchd daemon.
#
# @author  Steve Grunwell (Original Author)
# @author  Tobias Hochguerel <tobias.hochguertel@googlemail.com> (Fork Maintainer)
# @license MIT

DIR="$(cd "$(dirname "$0")" || return; pwd -P)"
PLIST="com.stevegrunwell.asimov.plist"
PLIST_ZSH="com.tobiashochguertel.asimov-zsh.plist"

# Parse arguments
USE_ZSH=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --zsh)
            USE_ZSH=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --zsh     Install the optimized ZSH version (asimov-zsh)"
            echo "  -h        Show this help message"
            echo ""
            echo "The ZSH version requires: fd, zsh"
            echo "Install fd via: brew install fd"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if $USE_ZSH; then
    # Check for fd dependency
    if ! command -v fd &>/dev/null; then
        echo -e "\\033[0;31mError: 'fd' is required for asimov-zsh but not installed.\\033[0m"
        echo "Install it via: brew install fd"
        exit 1
    fi

    # Verify that Asimov-ZSH is executable.
    chmod +x "${DIR}/asimov-zsh"

    # Symlink Asimov-ZSH into /usr/local/bin.
    echo -e "\\033[0;36mSymlinking ${DIR}/asimov-zsh to /usr/local/bin/asimov\\033[0m"
    ln -si "${DIR}/asimov-zsh" /usr/local/bin/asimov

    # If the original daemon is loaded, unload it first
    if launchctl list | grep -q com.stevegrunwell.asimov; then
        echo -e "\\n\\033[0;36mUnloading original bash daemon\\033[0m";
        launchctl unload "${DIR}/${PLIST}" 2>/dev/null || true
    fi

    # If zsh daemon is already loaded, unload first.
    if launchctl list | grep -q com.tobiashochguertel.asimov-zsh; then
        echo -e "\\n\\033[0;36mUnloading current instance of ${PLIST_ZSH}\\033[0m";
        launchctl unload "${DIR}/${PLIST_ZSH}"
    fi

    # Load the ZSH .plist file.
    launchctl load "${DIR}/${PLIST_ZSH}" && echo -e "\\n\\033[0;32mAsimov-ZSH daemon has been loaded!\\033[0m";

    # Run Asimov-ZSH for the first time.
    echo -e "\\n\\033[0;36mRunning asimov-zsh for the first time...\\033[0m"
    "${DIR}/asimov-zsh"
else
    # Original bash installation

    # Verify that Asimov is executable.
    chmod +x "${DIR}/asimov"

    # Symlink Asimov into /usr/local/bin.
    echo -e "\\033[0;36mSymlinking ${DIR} to /usr/local/bin/asimov\\033[0m"
    ln -si "${DIR}/asimov" /usr/local/bin/asimov

    # If the ZSH daemon is loaded, unload it first
    if launchctl list | grep -q com.tobiashochguertel.asimov-zsh; then
        echo -e "\\n\\033[0;36mUnloading ZSH daemon\\033[0m";
        launchctl unload "${DIR}/${PLIST_ZSH}" 2>/dev/null || true
    fi

    # If it's already loaded, unload first.
    if launchctl list | grep -q com.stevegrunwell.asimov; then
        echo -e "\\n\\033[0;36mUnloading current instance of ${PLIST}\\033[0m";
        launchctl unload "${DIR}/${PLIST}"
    fi

    # Load the .plist file.
    launchctl load "${DIR}/${PLIST}" && echo -e "\\n\\033[0;32mAsimov daemon has been loaded!\\033[0m";

    # Run Asimov for the first time.
    "${DIR}/asimov"
fi
