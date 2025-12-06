# Troubleshooting Guide

This guide covers common issues when using asimov-zsh and their solutions.

## Service Failures

### Issue: Service fails with exit code 1 (December 2025)

**Symptoms:**
- `launchctl list | grep asimov` shows exit code 1
- Service appears not to be running
- Error message: "General error - Program: /usr/local/bin/asimov"

**Root Cause:**
The asimov-zsh script depends on the `fd` command, which is typically installed via Homebrew at `/opt/homebrew/bin/fd`. However, launchd services run with a minimal PATH that only includes `/usr/bin:/bin:/usr/sbin:/sbin`, which does not include Homebrew's bin directories.

**Solution:**
Add the PATH environment variable to the plist file to include Homebrew's bin directory:

```xml
<key>EnvironmentVariables</key>
<dict>
    <!-- PATH needs to include Homebrew bin for fd command -->
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    
    <!-- Other environment variables... -->
</dict>
```

**Fixed in:**
- Version 0.11.0+ (plist file updated to include proper PATH)

**Manual Fix:**
If you installed before this fix:

```sh
cd ~/asimov  # or wherever you cloned the repo
./install.sh --upgrade
```

Or manually update your installed plist:
```sh
# Edit the plist file
nano ~/Library/LaunchAgents/com.tobiashochguertel.asimov-zsh.plist

# Add PATH variable (see XML above)

# Reload the service
launchctl unload ~/Library/LaunchAgents/com.tobiashochguertel.asimov-zsh.plist
launchctl load ~/Library/LaunchAgents/com.tobiashochguertel.asimov-zsh.plist
```

**Verification:**
```sh
# Check service status
launchctl list | grep asimov

# Should show exit code "(never exited)" or 0 instead of 1

# Check detailed service info
launchctl print gui/$(id -u)/com.tobiashochguertel.asimov-zsh | grep "last exit code"
```

## Dependency Issues

### Missing fd command

**Symptoms:**
- Service fails to start
- Manual run shows error: "fd: command not found"

**Solution:**
```sh
brew install fd
```

### Missing zsh

**Symptoms:**
- Script fails with "/usr/bin/env: zsh: No such file or directory"

**Solution:**
ZSH is included by default on macOS 10.15 (Catalina) and later. For older systems:
```sh
brew install zsh
```

## Performance Issues

### Slow scans

If scans are taking too long, check your configuration:

```sh
# View current service configuration
launchctl print gui/$(id -u)/com.tobiashochguertel.asimov-zsh | grep -A20 "environment ="
```

Recommended optimizations (already set in default plist):
- `ASIMOV_OPT_CACHE=true` - Enable caching
- `ASIMOV_OPT_SQLITE=true` - Use SQLite for O(log n) lookups
- `ASIMOV_OPT_BATCH=true` - Batch operations
- `ASIMOV_OPT_SKIP_SIZE=true` - Skip size calculations

See [how-to-improve-the-performance-of-asimov.md](../how-to-improve-the-performance-of-asimov.md) for more details.

## Logging Issues

### Log file not being created

**Check if directory exists:**
```sh
ls -la ~/.local/log/
```

**Create if missing:**
```sh
mkdir -p ~/.local/log
```

**View logs:**
```sh
# View JSON logs
tail -f ~/.local/log/asimov.log

# Pretty-print JSON logs
tail -f ~/.local/log/asimov.log | jq .
```

## Service Management

### Check if service is loaded
```sh
launchctl list | grep asimov
```

### View service details
```sh
launchctl print gui/$(id -u)/com.tobiashochguertel.asimov-zsh
```

### Manually trigger service
```sh
launchctl start com.tobiashochguertel.asimov-zsh
```

### Reload service after config changes
```sh
launchctl unload ~/Library/LaunchAgents/com.tobiashochguertel.asimov-zsh.plist
launchctl load ~/Library/LaunchAgents/com.tobiashochguertel.asimov-zsh.plist
```

### Completely remove and reinstall
```sh
cd ~/asimov
./install.sh --uninstall
./install.sh --zsh
```

## Cache Issues

### Reset cache
```sh
# Remove SQLite cache
rm ~/.cache/asimov.db

# Or remove file-based cache
rm ~/.cache/asimov-exclusions

# Reinitialize cache
ASIMOV_OPT_SQLITE=true ASIMOV_INIT_CACHE=true asimov
```

### Check cache status
```sh
# SQLite cache
sqlite3 ~/.cache/asimov.db "SELECT COUNT(*) FROM exclusions"

# File cache
wc -l ~/.cache/asimov-exclusions
```

## Getting Help

If you encounter issues not covered here:

1. Check the service logs: `tail -f ~/.local/log/asimov.log`
2. Run asimov manually with verbose output: `ASIMOV_VERBOSE=true asimov`
3. Check system logs: `log show --predicate 'process == "asimov"' --last 1h`
4. Open an issue at: https://github.com/tobiashochguertel/asimov/issues

Include the following information:
- macOS version: `sw_vers`
- asimov version: `asimov --version`
- Service status: `launchctl list | grep asimov`
- Recent logs from `~/.local/log/asimov.log`
