# Migration Guide: From Original Asimov to Optimized ZSH Version

This guide helps users who are currently using the original `asimov` (bash version) migrate to the optimized `asimov-zsh` version.

## Table of Contents

1. [Why Migrate?](#why-migrate)
2. [Pre-Migration Checklist](#pre-migration-checklist)
3. [Migration Steps](#migration-steps)
4. [Importing Existing Exclusions](#importing-existing-exclusions)
5. [Verifying Migration](#verifying-migration)
6. [Rollback (If Needed)](#rollback-if-needed)

---

## Why Migrate?

The optimized ZSH version offers several advantages:

| Feature | Original (Bash) | Optimized (ZSH) |
|---------|-----------------|-----------------|
| Directory search | `find` (sequential) | `fd` (parallel, 2-3x faster) |
| Exclusion lookup | `tmutil isexcluded` per dir | Cached in-memory (O(1)) |
| Size calculation | `du` (slow for large dirs) | Skippable or uses `dust` |
| Configuration | Limited | Extensive via env variables |
| Progress info | Basic | Verbose mode available |

**Estimated performance improvement: 2-3x faster** on typical developer machines with many projects.

---

## Pre-Migration Checklist

Before migrating, ensure you have:

- [ ] **macOS 10.13+** (High Sierra or newer)
- [ ] **ZSH** installed (default on macOS Catalina+)
- [ ] **fd** installed: `brew install fd`
- [ ] **Backup of current exclusions** (see below)

### Export Your Current Exclusions

Before making any changes, export your current Time Machine exclusions:

```bash
# Export all current exclusions to a file
sudo mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'" > ~/Desktop/tm-exclusions-backup.txt

# Count how many exclusions you have
wc -l ~/Desktop/tm-exclusions-backup.txt
```

This backup ensures you can verify nothing was lost during migration.

---

## Migration Steps

### Step 1: Install Dependencies

```bash
# Install fd (required for asimov-zsh)
brew install fd

# Verify fd is installed
fd --version
```

### Step 2: Get the Fork

If you installed asimov via Homebrew:

```bash
# Unload the Homebrew-managed daemon
sudo brew services stop asimov

# Clone the fork
git clone https://github.com/tobiashochguertel/asimov.git ~/asimov-fork
cd ~/asimov-fork
```

If you installed asimov manually from the original repo:

```bash
# Navigate to your asimov directory
cd /path/to/your/asimov

# Add the fork as a remote and fetch
git remote add fork https://github.com/tobiashochguertel/asimov.git
git fetch fork
git checkout fork/main
```

### Step 3: Unload the Old Daemon

```bash
# Check if the old daemon is running
launchctl list | grep asimov

# Unload the old daemon
launchctl unload ~/Library/LaunchAgents/com.stevegrunwell.asimov.plist 2>/dev/null
# Or if installed system-wide:
sudo launchctl unload /Library/LaunchDaemons/com.stevegrunwell.asimov.plist 2>/dev/null
```

### Step 4: Install the ZSH Version

```bash
cd ~/asimov-fork  # or wherever you cloned/updated

# Install the optimized ZSH version
./install.sh --zsh
```

This will:
- Symlink `asimov-zsh` to `/usr/local/bin/asimov`
- Load the new launchd daemon with optimizations enabled
- Run asimov-zsh for the first time

### Step 5: Initialize the Cache

For optimal performance, initialize the cache from your existing exclusions:

```bash
# Initialize cache from current Time Machine exclusions
ASIMOV_INIT_CACHE=true asimov
```

This pre-populates the cache so subsequent runs are faster.

---

## Importing Existing Exclusions

Your existing Time Machine exclusions are **automatically preserved**. They are stored as extended attributes (`xattr`) on the directories themselves, not in the asimov script.

### Verify Exclusions Were Preserved

```bash
# List current exclusions in your home directory
ASIMOV_ROOT=~ ASIMOV_LIST_EXCLUSIONS=true ASIMOV_VERBOSE=true asimov

# Compare with your backup
diff <(sort ~/Desktop/tm-exclusions-backup.txt) \
     <(sudo mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'" | sort)
```

The output should show no differences (or only new exclusions added by the first run).

### If You Have a Custom Exclusion List

If you maintained a separate list of paths to exclude, you can import them:

```bash
# Create a script to import exclusions
while IFS= read -r path; do
    if [[ -d "$path" ]]; then
        tmutil addexclusion "$path"
        echo "Excluded: $path"
    fi
done < ~/my-custom-exclusions.txt
```

---

## Verifying Migration

### Test 1: Check the Daemon is Running

```bash
# Should show the new daemon
launchctl list | grep asimov

# Expected output:
# -    0    com.tobiashochguertel.asimov-zsh
```

### Test 2: Run a Dry-Run Scan

```bash
# Scan your home directory without making changes
ASIMOV_DRY_RUN=true ASIMOV_VERBOSE=true asimov
```

### Test 3: Verify Exclusion Count

```bash
# Count exclusions before and after
sudo mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'" | wc -l

# Should be equal to or greater than your backup count
```

### Test 4: Check a Known Excluded Directory

```bash
# Pick a directory you know was excluded
tmutil isexcluded ~/your-project/node_modules

# Expected output:
# [Excluded]  /Users/you/your-project/node_modules
```

---

## Rollback (If Needed)

If you encounter issues and need to return to the original bash version:

### Option 1: Use the Install Script

```bash
cd ~/asimov-fork
./install.sh  # Without --zsh flag installs the bash version
```

### Option 2: Manual Rollback

```bash
# Unload the ZSH daemon
launchctl unload ~/Library/LaunchAgents/com.tobiashochguertel.asimov-zsh.plist

# Remove the symlink
rm /usr/local/bin/asimov

# Reinstall original asimov via Homebrew
brew install asimov
sudo brew services start asimov
```

### Option 3: Return to Upstream

```bash
# If you cloned the fork
cd ~/asimov-fork
git remote add upstream https://github.com/stevegrunwell/asimov.git
git fetch upstream
git checkout upstream/main
./install.sh
```

---

## Troubleshooting

### "fd: command not found"

```bash
brew install fd
```

### "Permission denied" errors

The ZSH version doesn't require sudo for normal operation. If you see permission errors:

```bash
# Check file permissions
ls -la /usr/local/bin/asimov

# Fix if needed
chmod +x /usr/local/bin/asimov
```

### Daemon not starting

```bash
# Check for errors
launchctl list | grep asimov

# View daemon logs
log show --predicate 'subsystem == "com.apple.launchd"' --last 5m | grep asimov
```

### Cache issues

```bash
# Clear the cache and reinitialize
rm ~/.cache/asimov-exclusions
ASIMOV_INIT_CACHE=true asimov
```

---

## Next Steps

After successful migration, read the [User Guide](USER-GUIDE.md) to learn:

- How to maintain asimov over time
- Best practices for Time Machine with development projects
- Advanced configuration options

---

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/tobiashochguertel/asimov/issues)
- **Original Project**: [stevegrunwell/asimov](https://github.com/stevegrunwell/asimov)
