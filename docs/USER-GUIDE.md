# Asimov User Guide: Long-Term Maintenance

This guide explains how to use and maintain Asimov effectively over time, ensuring your development dependencies stay excluded from Time Machine backups without constant manual intervention.

## Table of Contents

1. [Understanding How Asimov Works](#understanding-how-asimov-works)
2. [Installation: Set It and Forget It?](#installation-set-it-and-forget-it)
3. [Recommended Maintenance Schedule](#recommended-maintenance-schedule)
4. [Working with Asimov Day-to-Day](#working-with-asimov-day-to-day)
5. [Managing Your Exclusion List](#managing-your-exclusion-list)
6. [Advanced Configuration](#advanced-configuration)
7. [Best Practices](#best-practices)
8. [FAQ](#faq)

---

## Understanding How Asimov Works

### What Asimov Does

Asimov automatically finds and excludes development dependency directories from Time Machine backups:

```
Your Project/
├── package.json          ← Sentinel file (indicates Node.js project)
├── node_modules/         ← EXCLUDED from Time Machine
├── src/
│   └── index.js          ← Backed up normally
└── README.md             ← Backed up normally
```

### How Exclusions Work on macOS

Time Machine exclusions are stored in two ways:

1. **Extended Attributes (xattr)** - Attached directly to the file/directory
   - Created by: `tmutil addexclusion /path`
   - **Survives if you move the directory**
   - This is what Asimov uses

2. **Fixed-Path Exclusions** - Stored in system preferences
   - Created by: `tmutil addexclusion -p /path`
   - **Does NOT survive if you move the directory**
   - Asimov does not use this method

### The Exclusion Lifecycle

```
1. You create a new project
   └── npm install creates node_modules/
   
2. Asimov runs (daily or manually)
   └── Finds node_modules/ next to package.json
   └── Calls: tmutil addexclusion node_modules/
   
3. Time Machine runs
   └── Sees [Excluded] attribute
   └── Skips node_modules/ directory
   
4. You delete the project
   └── node_modules/ is deleted
   └── Exclusion is automatically gone (it was on the directory)
```

---

## Installation: Set It and Forget It?

### The Short Answer: Yes, Mostly

Once installed with the launchd daemon, Asimov will:

- ✅ Run automatically every 24 hours
- ✅ Find new dependency directories in your home folder
- ✅ Skip directories that are already excluded
- ✅ Handle deleted projects gracefully (exclusions are on the directories)

### What Asimov Does NOT Do Automatically

- ❌ Scan directories outside `$HOME` (configurable)
- ❌ Exclude custom patterns you haven't configured
- ❌ Run immediately when you create a new project
- ❌ Clean up stale cache entries

### Recommended: Initial Setup + Occasional Check

```bash
# Initial setup (one time)
./install.sh --zsh

# Initialize cache from existing exclusions
ASIMOV_INIT_CACHE=true asimov

# Verify it's working
launchctl list | grep asimov
```

Then check in **once every few months** (see maintenance schedule below).

---

## Recommended Maintenance Schedule

### Daily (Automatic)
- Asimov runs via launchd daemon
- New dependency directories are excluded
- No action needed from you

### Monthly (Optional, 5 minutes)
Quick health check:

```bash
# Check daemon is running
launchctl list | grep asimov

# See recent exclusions (quick scan)
ASIMOV_ROOT=~/projects ASIMOV_DRY_RUN=true asimov | head -20
```

### Quarterly (Recommended, 15 minutes)
More thorough review:

```bash
# 1. List all current exclusions
ASIMOV_LIST_EXCLUSIONS=true ASIMOV_VERBOSE=true asimov > ~/Desktop/quarterly-exclusions.txt

# 2. Check exclusion count trend
wc -l ~/Desktop/quarterly-exclusions.txt

# 3. Refresh cache
rm ~/.cache/asimov-exclusions
ASIMOV_INIT_CACHE=true asimov

# 4. Run full scan with verbose output
ASIMOV_VERBOSE=true asimov
```

### Yearly (Recommended, 30 minutes)
Annual review:

```bash
# 1. Check for asimov updates
cd ~/asimov-fork  # or wherever you installed
git fetch origin
git log HEAD..origin/main --oneline

# 2. Update if new version available
git pull
./install.sh --zsh

# 3. Review Time Machine backup size
tmutil listbackups | tail -5
tmutil compare  # Compare latest backup to current state

# 4. Clean up old projects
# Review exclusions and remove stale paths manually if needed
```

---

## Working with Asimov Day-to-Day

### Scenario 1: Created a New Project

**What happens automatically:**
- Asimov will find it on the next daily run
- The dependency directory will be excluded within 24 hours

**If you can't wait:**
```bash
# Run asimov manually
asimov

# Or exclude just that directory
tmutil addexclusion ~/projects/new-project/node_modules
```

### Scenario 2: Moved a Project

**What happens:**
- The exclusion attribute moves with the directory ✅
- No action needed

**Verify:**
```bash
tmutil isexcluded ~/new-location/project/node_modules
# Should show: [Excluded]
```

### Scenario 3: Deleted a Project

**What happens:**
- The directory is gone, so is the exclusion ✅
- No action needed

**If the project is in trash:**
```bash
# Exclusion still applies until you empty trash
tmutil isexcluded ~/.Trash/old-project/node_modules
```

### Scenario 4: Cloned a Project with Existing node_modules

**What happens:**
- If cloned from a backup, exclusion attribute is preserved
- If cloned from git, no exclusion exists yet
- Asimov will exclude on next run

**To exclude immediately:**
```bash
asimov  # Run asimov
# Or directly:
tmutil addexclusion ~/projects/cloned-project/node_modules
```

### Scenario 5: Working Outside Home Directory

By default, Asimov only scans `$HOME`. For other locations:

```bash
# Scan a specific directory
ASIMOV_ROOT=/Volumes/ExternalSSD/projects asimov

# Or configure for regular scans (edit the plist)
```

---

## Managing Your Exclusion List

### View Current Exclusions

```bash
# All exclusions (system-wide)
sudo mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'"

# Using asimov-zsh's list mode
ASIMOV_LIST_EXCLUSIONS=true ASIMOV_VERBOSE=true asimov

# Filter by type
sudo mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'" | grep node_modules
```

### Export Exclusions

```bash
# Export to file
sudo mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'" > ~/tm-exclusions.txt

# Export with metadata
ASIMOV_LIST_EXCLUSIONS=true ASIMOV_VERBOSE=true asimov > ~/asimov-report.txt
```

### Remove an Exclusion

```bash
# Remove exclusion from a specific directory
tmutil removeexclusion /path/to/directory

# Verify it's now included
tmutil isexcluded /path/to/directory
# Should show: [Included]
```

### Add Custom Exclusions

Asimov handles standard dependency directories. For custom exclusions:

```bash
# Exclude a specific directory
tmutil addexclusion ~/Downloads/large-temp-files

# Exclude a pattern (manual)
fd -t d 'logs$' ~/projects | while read dir; do
    tmutil addexclusion "$dir"
done
```

### Clean Up Stale Exclusions

Over time, you might have exclusions for directories that no longer exist:

```bash
# Find exclusions pointing to non-existent paths
sudo mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'" | while read path; do
    if [[ ! -e "$path" ]]; then
        echo "Stale: $path"
    fi
done
```

Note: These stale entries don't cause problems—they're just references in Spotlight's index that will eventually be cleaned up.

---

## Advanced Configuration

### Environment Variables (ZSH Version)

| Variable | Default | Description |
|----------|---------|-------------|
| `ASIMOV_ROOT` | `$HOME` | Directory to scan |
| `ASIMOV_DRY_RUN` | `false` | Don't actually exclude, just show |
| `ASIMOV_VERBOSE` | `false` | Show detailed progress |
| `ASIMOV_LIST_EXCLUSIONS` | `false` | List current exclusions instead of scanning |
| `ASIMOV_INIT_CACHE` | `false` | Initialize cache from current exclusions |
| `ASIMOV_STATUS` | `false` | Show service status and statistics |
| `ASIMOV_OPT_CACHE` | `false` | Enable caching |
| `ASIMOV_OPT_MMAP` | `false` | Use in-memory cache |
| `ASIMOV_OPT_SKIP_SIZE` | `false` | Don't calculate directory sizes |
| `ASIMOV_OPT_INCREMENTAL` | `false` | Only scan recently modified dirs |
| `ASIMOV_OPT_INCREMENTAL_DAYS` | `7` | Days threshold for incremental |
| `ASIMOV_OPT_BATCH` | `false` | Batch tmutil and du operations |
| `ASIMOV_OPT_BATCH_SIZE` | `50` | Number of paths per batch |
| `ASIMOV_OPT_PARALLEL` | `false` | Run tmutil calls in parallel |
| `ASIMOV_OPT_PARALLEL_JOBS` | `4` | Max parallel jobs |
| `ASIMOV_OPT_GITIGNORE` | `false` | Use fd's gitignore awareness |
| `ASIMOV_OPT_DUST` | `false` | Use dust instead of du for size |
| `ASIMOV_LOG_FILE` | (empty) | Path to log file (empty = disabled) |
| `ASIMOV_LOG_FORMAT` | `text` | Log format: `text` or `json` |
| `ASIMOV_STATUS_TRUNCATE` | `true` | Truncate long paths in status output |
| `ASIMOV_STATUS_TRUNCATE_LEN` | `55` | Max path length before truncation |
| `NO_COLOR` | (unset) | Disable colors when set (any value) |

### Customize the Daemon

Edit the launchd plist to change behavior:

```bash
# For ZSH version
nano ~/asimov-fork/com.tobiashochguertel.asimov-zsh.plist
```

Example: Add custom root directory:
```xml
<key>EnvironmentVariables</key>
<dict>
    <key>ASIMOV_ROOT</key>
    <string>/Users/you/all-projects</string>
    <!-- ... other settings ... -->
</dict>
```

Reload after changes:
```bash
launchctl unload ~/asimov-fork/com.tobiashochguertel.asimov-zsh.plist
launchctl load ~/asimov-fork/com.tobiashochguertel.asimov-zsh.plist
```

### Multiple Scan Directories

To scan multiple directories, create a wrapper script:

```bash
#!/usr/bin/env zsh
# ~/bin/asimov-all

# Scan primary work directory
ASIMOV_ROOT=~/work asimov

# Scan secondary directory
ASIMOV_ROOT=~/personal-projects asimov

# Scan external drive (if mounted)
if [[ -d /Volumes/Projects ]]; then
    ASIMOV_ROOT=/Volumes/Projects asimov
fi
```

---

## Best Practices

### DO ✅

1. **Let asimov run automatically** - The daemon handles 99% of cases
2. **Use dry-run for testing** - `ASIMOV_DRY_RUN=true asimov`
3. **Initialize cache after migration** - Speeds up subsequent runs
4. **Keep fd updated** - `brew upgrade fd`
5. **Review quarterly** - Quick sanity check

### DON'T ❌

1. **Don't exclude manually what asimov handles** - Let asimov manage it
2. **Don't use `-p` flag with tmutil** - Fixed-path exclusions don't move
3. **Don't disable Time Machine** - Just exclude what you don't need
4. **Don't exclude source code** - Only exclude regeneratable dependencies
5. **Don't run asimov too frequently** - Once daily is sufficient

### What to Exclude vs What to Backup

| Exclude (Regeneratable) | Backup (Important) |
|------------------------|-------------------|
| `node_modules/` | `package.json`, `package-lock.json` |
| `vendor/` (PHP/Go) | `composer.json`, `go.mod` |
| `.venv/`, `venv/` | `requirements.txt`, `pyproject.toml` |
| `target/` (Rust/Java) | `Cargo.toml`, `pom.xml` |
| `build/`, `dist/` | Source code |
| `.gradle/` | `build.gradle` |

---

## FAQ

### Q: Do I need to run asimov after every `npm install`?

**A:** No. The daemon runs daily and will catch new `node_modules` directories. If you want immediate exclusion, run `asimov` manually or use `tmutil addexclusion` directly.

### Q: What happens if I reinstall macOS?

**A:** Extended attributes (exclusions) are preserved if you migrate your data. If you do a clean install, run asimov once to re-exclude everything.

### Q: Does asimov slow down my Mac?

**A:** No. The ZSH version typically completes in seconds. The daemon only runs once per day and uses minimal resources.

### Q: Can I exclude directories asimov doesn't know about?

**A:** Yes, use `tmutil addexclusion /path` directly. Asimov won't interfere with manual exclusions.

### Q: Why are some directories still being backed up?

**A:** Check:
1. Is there a sentinel file? (e.g., `package.json` next to `node_modules`)
2. Is the directory name correct? (e.g., `node_modules` not `node-modules`)
3. Run `tmutil isexcluded /path` to verify status

### Q: How much backup space does asimov save?

**A:** Varies widely. A typical developer with 10-20 projects might save 5-50GB. Check with:
```bash
# Sum up sizes of excluded directories
ASIMOV_LIST_EXCLUSIONS=true asimov | xargs -I{} du -sh {} 2>/dev/null
```

### Q: Can I use asimov with Time Machine alternatives (Carbon Copy Cloner, etc.)?

**A:** Asimov specifically uses macOS's `tmutil` which only affects Time Machine. For other backup tools, check their documentation for exclusion methods.

---

## Quick Reference Card

```bash
# Run asimov manually
asimov

# Dry run (see what would be excluded)
ASIMOV_DRY_RUN=true asimov

# Verbose output
ASIMOV_VERBOSE=true asimov

# List current exclusions
ASIMOV_LIST_EXCLUSIONS=true asimov

# Initialize cache
ASIMOV_INIT_CACHE=true asimov

# Show service status and statistics
ASIMOV_STATUS=true asimov

# Scan specific directory
ASIMOV_ROOT=~/projects asimov

# Enable logging
ASIMOV_LOG_FILE=~/.local/log/asimov.log asimov

# Disable colors
NO_COLOR=1 asimov

# Check if daemon is running
launchctl list | grep asimov

# Check specific path
tmutil isexcluded /path/to/directory

# Remove exclusion
tmutil removeexclusion /path/to/directory

# List all Time Machine exclusions
sudo mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'"
```

---

## Getting Help

- **Documentation**: [README.md](../README.md)
- **Migration Guide**: [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md)
- **Performance Docs**: [how-to-improve-the-performance-of-asimov.md](../how-to-improve-the-performance-of-asimov.md)
- **Issues**: [GitHub Issues](https://github.com/tobiashochguertel/asimov/issues)
