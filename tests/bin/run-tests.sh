#!/usr/bin/env sh

# Print a section header
section() {
  printf "\\n\\033[0;36m%s\\033[0;0m\\n" "$1"
}

# Print a warning message
notice() {
  printf "\\033[0;33m%s\\033[0;0m" "$1"
}

success() {
  printf "\\033[0;32m%s\\033[0;0m\\n" "$1"
}

section "Running unit tests:"

if type bats > /dev/null; then
  bats tests/sentinels.bats tests/behavior.bats tests/format.bats tests/plist.bats || exit 1
else
  notice "Bats is not installed.\\nYou may install it by running: brew install bats-core"
fi

section "Checking coding standards:"

if type shellcheck > /dev/null; then
  shellcheck asimov scripts/install.sh scripts/install-remote.sh scripts/uninstall.sh tests/test_helper.bash tests/bin/run-tests.sh tests/bin/tmutil tests/bin/mdfind || exit 1
  success "No problems detected!"
else
  notice "Shellcheck is not installed.\\nPlease visit https://www.shellcheck.net/ for installation options."
fi
