#!/usr/bin/env zsh
# =============================================================================
# migrate-to-asimov-zsh.zsh
#
# Migration script from original asimov (Homebrew) to optimized asimov-zsh
# Creates a tmux session for long-running full scan
#
# @author  Tobias Hochguertel <tobias.hochguertel@googlemail.com> (Fork Maintainer)
# @license MIT
#
# Usage: ./migrate-to-asimov-zsh.zsh [--dry-run]
# =============================================================================

set -e

SCRIPT_DIR="${0:A:h}"
SESSION_NAME="asimov-migration"
LOG_FILE="${SCRIPT_DIR}/migration-$(date +%Y%m%d-%H%M%S).log"
CACHE_FILE="${HOME}/.cache/asimov-exclusions"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Parse arguments
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        -h|--help)
            echo "Usage: $0 [--dry-run]"
            echo ""
            echo "Migrates from Homebrew asimov to optimized asimov-zsh"
            echo ""
            echo "Options:"
            echo "  --dry-run  Show what would be done without making changes"
            echo "  -h         Show this help"
            exit 0
            ;;
    esac
done

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${CYAN}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ✓ $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_warn() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ⚠ $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ✗ $1"
    echo -e "${RED}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

# =============================================================================
# Pre-flight checks
# =============================================================================

log "Starting asimov-zsh migration..."
log "Log file: $LOG_FILE"
echo ""

# Check dependencies
log "Checking dependencies..."

if ! command -v fd &>/dev/null; then
    log_error "fd is not installed. Please run: brew install fd"
    exit 1
fi
log_success "fd is installed: $(fd --version)"

if ! command -v zsh &>/dev/null; then
    log_error "zsh is not installed"
    exit 1
fi
log_success "zsh is installed: $(zsh --version | head -1)"

if ! command -v tmux &>/dev/null; then
    log_error "tmux is not installed. Please run: brew install tmux"
    exit 1
fi
log_success "tmux is installed: $(tmux -V)"

if [[ ! -x "${SCRIPT_DIR}/asimov-zsh" ]]; then
    log_error "asimov-zsh not found at ${SCRIPT_DIR}/asimov-zsh"
    exit 1
fi
log_success "asimov-zsh found"

echo ""

# =============================================================================
# Backup current exclusions
# =============================================================================

log "Backing up current Time Machine exclusions..."
BACKUP_FILE="${SCRIPT_DIR}/tm-exclusions-backup-$(date +%Y%m%d-%H%M%S).txt"

if $DRY_RUN; then
    log_warn "[DRY-RUN] Would backup exclusions to: $BACKUP_FILE"
else
    mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'" > "$BACKUP_FILE" 2>/dev/null
    EXCLUSION_COUNT=$(wc -l < "$BACKUP_FILE" | tr -d ' ')
    log_success "Backed up $EXCLUSION_COUNT exclusions to: $BACKUP_FILE"
fi

echo ""

# =============================================================================
# Stop Homebrew asimov if running
# =============================================================================

log "Checking for Homebrew asimov service..."

if brew services list 2>/dev/null | grep -q "asimov.*started"; then
    log "Stopping Homebrew asimov service..."
    if $DRY_RUN; then
        log_warn "[DRY-RUN] Would run: sudo brew services stop asimov"
    else
        sudo brew services stop asimov 2>/dev/null || true
        log_success "Stopped Homebrew asimov service"
    fi
else
    log_success "Homebrew asimov service not running"
fi

# Unload any existing launchd daemons
if launchctl list 2>/dev/null | grep -q "com.stevegrunwell.asimov"; then
    log "Unloading original asimov daemon..."
    if $DRY_RUN; then
        log_warn "[DRY-RUN] Would unload com.stevegrunwell.asimov"
    else
        launchctl unload ~/Library/LaunchAgents/com.stevegrunwell.asimov.plist 2>/dev/null || true
        launchctl unload "${SCRIPT_DIR}/com.stevegrunwell.asimov.plist" 2>/dev/null || true
        log_success "Unloaded original asimov daemon"
    fi
fi

if launchctl list 2>/dev/null | grep -q "com.tobiashochguertel.asimov-zsh"; then
    log "Unloading existing asimov-zsh daemon..."
    if $DRY_RUN; then
        log_warn "[DRY-RUN] Would unload com.tobiashochguertel.asimov-zsh"
    else
        launchctl unload "${SCRIPT_DIR}/com.tobiashochguertel.asimov-zsh.plist" 2>/dev/null || true
        log_success "Unloaded existing asimov-zsh daemon"
    fi
fi

echo ""

# =============================================================================
# Initialize cache from existing exclusions
# =============================================================================

log "Initializing cache from current exclusions..."

if $DRY_RUN; then
    log_warn "[DRY-RUN] Would initialize cache at: $CACHE_FILE"
else
    mkdir -p "${CACHE_FILE:h}" 2>/dev/null || true
    mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'" 2>/dev/null | \
        grep "^${HOME}" > "$CACHE_FILE" || true
    CACHE_COUNT=$(wc -l < "$CACHE_FILE" 2>/dev/null | tr -d ' ' || echo "0")
    log_success "Initialized cache with $CACHE_COUNT entries"
fi

echo ""

# =============================================================================
# Create symlink
# =============================================================================

log "Creating symlink to asimov-zsh..."

if $DRY_RUN; then
    log_warn "[DRY-RUN] Would symlink ${SCRIPT_DIR}/asimov-zsh to /usr/local/bin/asimov"
else
    # Remove existing symlink if present
    if [[ -L /usr/local/bin/asimov ]]; then
        rm /usr/local/bin/asimov
    fi

    # Create directory if needed
    sudo mkdir -p /usr/local/bin 2>/dev/null || true

    # Create symlink
    ln -sf "${SCRIPT_DIR}/asimov-zsh" /usr/local/bin/asimov
    log_success "Symlinked asimov-zsh to /usr/local/bin/asimov"
fi

echo ""

# =============================================================================
# Create tmux session for full scan
# =============================================================================

log "Creating tmux session for full home directory scan..."

TMUX_SCRIPT=$(mktemp)
cat > "$TMUX_SCRIPT" << 'EOFSCRIPT'
#!/usr/bin/env zsh
# Full scan script for tmux session

echo "=============================================="
echo "Asimov-ZSH Full Home Directory Scan"
echo "Started: $(date)"
echo "=============================================="
echo ""

export ASIMOV_ROOT="$HOME"
export ASIMOV_VERBOSE=true
export ASIMOV_OPT_CACHE=true
export ASIMOV_OPT_SQLITE=true
export ASIMOV_OPT_SKIP_SIZE=true
export ASIMOV_OPT_BATCH=true
export ASIMOV_OPT_BATCH_SIZE=50
export ASIMOV_LOG_FILE="${HOME}/.local/log/asimov.log"
export ASIMOV_LOG_FORMAT=json

# Create log directory
mkdir -p "${HOME}/.local/log" 2>/dev/null || true

echo "Configuration:"
echo "  ASIMOV_ROOT=$ASIMOV_ROOT"
echo "  ASIMOV_OPT_CACHE=$ASIMOV_OPT_CACHE"
echo "  ASIMOV_OPT_SQLITE=$ASIMOV_OPT_SQLITE"
echo "  ASIMOV_OPT_BATCH=$ASIMOV_OPT_BATCH"
echo "  ASIMOV_OPT_SKIP_SIZE=$ASIMOV_OPT_SKIP_SIZE"
echo "  ASIMOV_LOG_FILE=$ASIMOV_LOG_FILE"
echo ""

# Run the full scan
SCRIPT_DIR_INNER="SCRIPT_DIR_PLACEHOLDER"
"${SCRIPT_DIR_INNER}/asimov-zsh"

echo ""
echo "=============================================="
echo "Scan completed: $(date)"
echo "=============================================="

# Show summary
echo ""
echo "Summary:"
TOTAL=$(mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'" 2>/dev/null | wc -l | tr -d ' ')
echo "  Total Time Machine exclusions: $TOTAL"

if [[ -f ~/.cache/asimov.db ]]; then
    CACHED=$(sqlite3 ~/.cache/asimov.db "SELECT COUNT(*) FROM exclusions" 2>/dev/null || echo "0")
    echo "  SQLite cache entries: $CACHED"
elif [[ -f ~/.cache/asimov-exclusions ]]; then
    CACHED=$(wc -l < ~/.cache/asimov-exclusions | tr -d ' ')
    echo "  File cache entries: $CACHED"
fi

echo ""
echo "Press Enter to close this session, or keep it open to review output..."
read
EOFSCRIPT

# Replace placeholder with actual path
sed -i '' "s|SCRIPT_DIR_PLACEHOLDER|${SCRIPT_DIR}|g" "$TMUX_SCRIPT"
chmod +x "$TMUX_SCRIPT"

if $DRY_RUN; then
    log_warn "[DRY-RUN] Would create tmux session '$SESSION_NAME' running full scan"
    rm "$TMUX_SCRIPT"
else
    # Kill existing session if present
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

    # Create new tmux session
    tmux new-session -d -s "$SESSION_NAME" "zsh $TMUX_SCRIPT; rm $TMUX_SCRIPT"

    log_success "Created tmux session: $SESSION_NAME"
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Full scan running in background tmux session                  ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}║  To attach to the session:                                     ║${NC}"
    echo -e "${GREEN}║    ${CYAN}tmux attach -t ${SESSION_NAME}${GREEN}                          ║${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}║  To detach from session (keep it running):                     ║${NC}"
    echo -e "${GREEN}║    Press ${CYAN}Ctrl+B${GREEN} then ${CYAN}D${GREEN}                                       ║${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}║  To check if still running:                                    ║${NC}"
    echo -e "${GREEN}║    ${CYAN}tmux list-sessions${GREEN}                                       ║${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
fi

echo ""

# =============================================================================
# Load the new daemon
# =============================================================================

log "Loading asimov-zsh daemon for daily runs..."

if $DRY_RUN; then
    log_warn "[DRY-RUN] Would load ${SCRIPT_DIR}/com.tobiashochguertel.asimov-zsh.plist"
else
    launchctl load "${SCRIPT_DIR}/com.tobiashochguertel.asimov-zsh.plist" 2>/dev/null || true

    if launchctl list 2>/dev/null | grep -q "com.tobiashochguertel.asimov-zsh"; then
        log_success "Daemon loaded successfully"
    else
        log_warn "Daemon may not have loaded - check manually with: launchctl list | grep asimov"
    fi
fi

echo ""

# =============================================================================
# Summary
# =============================================================================

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Migration Complete!                         ║${NC}"
echo -e "${GREEN}╠════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                                                ║${NC}"
echo -e "${GREEN}║  What was done:                                                ║${NC}"
echo -e "${GREEN}║  • Backed up existing exclusions                               ║${NC}"
echo -e "${GREEN}║  • Initialized cache from current exclusions                   ║${NC}"
echo -e "${GREEN}║  • Symlinked asimov-zsh to /usr/local/bin/asimov               ║${NC}"
echo -e "${GREEN}║  • Started full home directory scan in tmux                    ║${NC}"
echo -e "${GREEN}║  • Loaded daily daemon                                         ║${NC}"
echo -e "${GREEN}║                                                                ║${NC}"
echo -e "${GREEN}║  Files created:                                                ║${NC}"
echo -e "${GREEN}║  • Log: ${LOG_FILE}${NC}"
if [[ -f "$BACKUP_FILE" ]]; then
echo -e "${GREEN}║  • Backup: ${BACKUP_FILE}${NC}"
fi
echo -e "${GREEN}║                                                                ║${NC}"
echo -e "${GREEN}║  Next steps:                                                   ║${NC}"
echo -e "${GREEN}║  1. Attach to tmux to monitor scan: ${CYAN}tmux attach -t ${SESSION_NAME}${NC}"
echo -e "${GREEN}║  2. After scan completes, verify with:                         ║${NC}"
echo -e "${GREEN}║     ${CYAN}ASIMOV_LIST_EXCLUSIONS=true asimov | wc -l${NC}"
echo -e "${GREEN}║                                                                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Log file: $LOG_FILE"
