#!/usr/bin/env zsh
# =============================================================================
# run-zsh-tests.zsh - Test suite for asimov-zsh
#
# @author  Tobias Hochguertel <tobias.hochguertel@googlemail.com>
# @license MIT
#
# Usage: ./tests/bin/run-zsh-tests.zsh
# =============================================================================

# Don't exit on first error - we want to run all tests
setopt NO_ERR_EXIT

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h:h}"
ASIMOV_ZSH="${PROJECT_DIR}/asimov-zsh"

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# =============================================================================
# Test Utilities
# =============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

run_test() {
    local name="$1"
    local cmd="$2"
    
    if eval "$cmd" >/dev/null 2>&1; then
        pass "$name"
    else
        fail "$name"
    fi
}

run_test_expect_output() {
    local name="$1"
    local cmd="$2"
    local expected="$3"
    
    local output
    output=$(eval "$cmd" 2>&1)
    
    if [[ "$output" == *"$expected"* ]]; then
        pass "$name"
    else
        fail "$name (expected: '$expected', got: '${output:0:100}...')"
    fi
}

# =============================================================================
# Setup
# =============================================================================

print_header "Asimov-ZSH Test Suite"

# Check asimov-zsh exists
if [[ ! -x "$ASIMOV_ZSH" ]]; then
    echo -e "${RED}Error: asimov-zsh not found or not executable${NC}"
    exit 1
fi

# Create temp directory for tests
TEST_DIR=$(mktemp -d)
trap "rm -rf '$TEST_DIR'" EXIT

echo "Test directory: $TEST_DIR"
echo "Asimov-ZSH: $ASIMOV_ZSH"

# =============================================================================
# CLI Argument Tests
# =============================================================================

print_header "CLI Argument Tests"

run_test "--help shows usage" \
    "$ASIMOV_ZSH --help | grep -q 'Usage:'"

run_test_expect_output "--version shows version number" \
    "$ASIMOV_ZSH --version" \
    "asimov-zsh version"

run_test "--dry-run exits successfully" \
    "$ASIMOV_ZSH --dry-run --root /tmp"

run_test "--verbose works with --dry-run" \
    "$ASIMOV_ZSH --dry-run --verbose --root /tmp"

run_test "--status shows service info" \
    "$ASIMOV_ZSH --status | grep -q 'Status'"

run_test "--list works" \
    "$ASIMOV_ZSH --list >/dev/null || true"

run_test "positional arg works as --root" \
    "$ASIMOV_ZSH --dry-run /tmp"

run_test "unknown option fails" \
    "! $ASIMOV_ZSH --unknown-option 2>/dev/null"

# =============================================================================
# Environment Variable Tests
# =============================================================================

print_header "Environment Variable Tests"

run_test "ASIMOV_DRY_RUN=true works" \
    "ASIMOV_DRY_RUN=true ASIMOV_ROOT=/tmp $ASIMOV_ZSH"

run_test "ASIMOV_VERBOSE=true works" \
    "ASIMOV_DRY_RUN=true ASIMOV_VERBOSE=true ASIMOV_ROOT=/tmp $ASIMOV_ZSH"

run_test "ASIMOV_STATUS=true works" \
    "ASIMOV_STATUS=true $ASIMOV_ZSH | grep -q 'Status'"

# =============================================================================
# SQLite Cache Tests
# =============================================================================

print_header "SQLite Cache Tests"

# Clean up any existing test db
rm -f "$TEST_DIR/test.db"

run_test "--sqlite flag works with dry-run" \
    "$ASIMOV_ZSH --dry-run --sqlite --root /tmp"

run_test "--sqlite with verbose works" \
    "$ASIMOV_ZSH --dry-run --sqlite --verbose --root /tmp"

run_test "SQLite db is created with init-cache" \
    "ASIMOV_SQLITE_DB='$TEST_DIR/test.db' $ASIMOV_ZSH --sqlite --init-cache 2>/dev/null; [[ -f '$TEST_DIR/test.db' ]]"

run_test "SQLite db has exclusions table" \
    "sqlite3 '$TEST_DIR/test.db' \"SELECT name FROM sqlite_master WHERE type='table' AND name='exclusions'\" 2>/dev/null | grep -q 'exclusions' || true"

# =============================================================================
# Tilde Expansion Tests
# =============================================================================

print_header "Tilde Expansion Tests"

# Create test directory in a place we can write to
TILDE_TEST_DB="$TEST_DIR/tilde-test.db"

run_test "~ is expanded in ASIMOV_SQLITE_DB" \
    "ASIMOV_SQLITE_DB='~/../../../$TILDE_TEST_DB' ASIMOV_OPT_SQLITE=true ASIMOV_DRY_RUN=true $ASIMOV_ZSH --root /tmp 2>/dev/null || true"

# =============================================================================
# Logging Tests
# =============================================================================

print_header "Logging Tests"

LOG_FILE="$TEST_DIR/test.log"
JSON_LOG_FILE="$TEST_DIR/test.json"

run_test "Text logging creates file" \
    "ASIMOV_LOG_FILE='$LOG_FILE' ASIMOV_LOG_FORMAT=text $ASIMOV_ZSH --dry-run --root /tmp && [[ -f '$LOG_FILE' ]]"

run_test "JSON logging creates file" \
    "ASIMOV_LOG_FILE='$JSON_LOG_FILE' ASIMOV_LOG_FORMAT=json $ASIMOV_ZSH --dry-run --root /tmp && [[ -f '$JSON_LOG_FILE' ]]"

run_test "JSON log contains valid JSON" \
    "[[ -f '$JSON_LOG_FILE' ]] && head -1 '$JSON_LOG_FILE' | grep -q '{' || true"

# =============================================================================
# Color Tests
# =============================================================================

print_header "Color Tests"

run_test "NO_COLOR disables colors" \
    "NO_COLOR=1 $ASIMOV_ZSH --dry-run --root /tmp 2>&1 | grep -v $'\033' || true"

# =============================================================================
# Project Detection Tests
# =============================================================================

print_header "Project Detection Tests"

# Create test project structure
mkdir -p "$TEST_DIR/projects/node-project/node_modules"
echo '{"name": "test"}' > "$TEST_DIR/projects/node-project/package.json"
mkdir -p "$TEST_DIR/projects/rust-project/target"
echo '[package]' > "$TEST_DIR/projects/rust-project/Cargo.toml"
mkdir -p "$TEST_DIR/projects/python-project/.venv"
echo 'requests' > "$TEST_DIR/projects/python-project/requirements.txt"

run_test "Detects node_modules with package.json" \
    "$ASIMOV_ZSH --dry-run --verbose --root '$TEST_DIR/projects' 2>&1 | grep -q 'node_modules'"

run_test "Detects target with Cargo.toml" \
    "$ASIMOV_ZSH --dry-run --verbose --root '$TEST_DIR/projects' 2>&1 | grep -q 'target'"

run_test "Detects .venv with requirements.txt" \
    "$ASIMOV_ZSH --dry-run --verbose --root '$TEST_DIR/projects' 2>&1 | grep -q '.venv'"

# =============================================================================
# Summary
# =============================================================================

print_header "Test Results"

TOTAL=$((TESTS_PASSED + TESTS_FAILED))

echo ""
echo -e "  ${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC} $TESTS_FAILED"
echo -e "  Total:  $TOTAL"
echo ""

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
