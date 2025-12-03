# How to Improve the Performance of Asimov

This document outlines strategies and optimizations to improve the performance of the `asimov` script, which excludes development dependency directories from Apple Time Machine backups.

## Implementation Status Overview

| #  | Improvement                                    | Status  | Notes                                                         |
|----|------------------------------------------------|---------|---------------------------------------------------------------|
| 1  | Use `fd` instead of `find`                     | ✅ Done | Parallel directory traversal with fd                          |
| 2  | Use ZSH Builtins                               | ✅ Done | Native string operations, pattern matching                    |
| 3  | Load ZSH Modules                               | ✅ Done | zsh/stat, zsh/datetime, zsh/parameter, zsh/zutil              |
| 4  | Precompute Directory/Sentinel Mappings         | ✅ Done | `SENTINEL_MAP` associative array                              |
| 5  | Batch Operations                               | ✅ Done | `ASIMOV_OPT_BATCH` for batch tmutil and du                    |
| 6  | Caching Exclusion Status                       | ✅ Done | `ASIMOV_OPT_CACHE` with file-based cache                      |
| 7  | Incremental Scanning                           | ✅ Done | `ASIMOV_OPT_INCREMENTAL` with `--changed-within`              |
| 8  | Parallel tmutil Calls                          | ✅ Done | `ASIMOV_OPT_PARALLEL` with job pool management                |
| 9  | Use `.gitignore` Awareness                     | ✅ Done | `ASIMOV_OPT_GITIGNORE` flag                                   |
| 10 | Memory-Mapped File Operations (In-Memory Hash) | ✅ Done | `ASIMOV_OPT_MMAP` with `MMAP_CACHE`                           |
| 11 | Alternative to `du` (dust)                     | ✅ Done | `ASIMOV_OPT_DUST` flag                                        |
| 12 | Configuration Refactoring                      | ✅ Done | `ASIMOV_CONFIG` associative array with sensible defaults      |
| 13 | Service Status & Monitoring                    | ✅ Done | `ASIMOV_STATUS=true` for launchd service info                 |
| 14 | Logging System                                 | ✅ Done | Text and JSON logging with `ASIMOV_LOG_FILE`                  |
| 15 | SQLite Cache                                   | ✅ Done | `ASIMOV_OPT_SQLITE` with `ASIMOV_SQLITE_DB`               |
| 16 | Color System Refactoring                       | ✅ Done | Global COLORS hash-map, NO_COLOR support, no colors in logs   |

## Done

The following improvements have been implemented in `asimov-zsh`:

### SQLite Cache

For very large exclusion lists (100,000+), SQLite provides indexed lookups and safe concurrent access.

**Configuration:**

```zsh
ASIMOV_OPT_CACHE=true
ASIMOV_OPT_SQLITE=true
ASIMOV_SQLITE_DB=~/.cache/asimov.db  # default location
```

**How it works:**

```zsh
# Initialize from current Time Machine exclusions
ASIMOV_INIT_CACHE=true ASIMOV_OPT_SQLITE=true ./asimov-zsh

# Run with SQLite caching
ASIMOV_OPT_CACHE=true ASIMOV_OPT_SQLITE=true ./asimov-zsh
```

**Implementation:**

- Creates SQLite database with indexed `path` column
- Uses batched transactions for efficient writes
- Single-query lookups: `SELECT 1 FROM exclusions WHERE path='...' LIMIT 1`
- Proper SQL escaping for paths with single quotes

Benefits:

- **Indexed lookups** - O(log n) instead of O(n) grep
- **ACID transactions** - Safe concurrent access from multiple processes
- **Compression** - SQLite compresses data automatically
- **Batched writes** - Reduces transaction overhead

When to use:

- 100,000+ exclusion entries
- Concurrent access from multiple asimov instances
- Systems with slow file I/O

### Service Status and Monitoring

Added a status command to check the running state of the `asimov-zsh` launchd service, view recent activity, and monitor performance.

**Implementation**: `ASIMOV_STATUS=true ./asimov-zsh` or set the environment variable.

```text
╔═══════════════════════════════════════════════════════════════╗
║                    Asimov-ZSH Status                          ║
╠═══════════════════════════════════════════════════════════════╣
║  Service:     com.tobiashochguertel.asimov-zsh                ║
║  Status:      Loaded (Last exit: success)                     ║
║  Schedule:    Every 24 hours                                  ║
║  Last Run:    2025-12-03T14:30:00 (2 hours ago)               ║
║                                                               ║
║  Statistics:                                                  ║
║    Total TM exclusions:    1,234                              ║
║    Cache entries:          1,100                              ║
║    Last scan duration:     45s                                ║
║                                                               ║
║  Recent Exclusions (last 5):                                  ║
║    ~/work/project-a/node_modules                              ║
║    ~/work/project-b/target                                    ║
║    ...                                                        ║
╚═══════════════════════════════════════════════════════════════╝
```

Features:

- **Service status** - Shows launchd service state (loaded/not loaded)
- **Schedule info** - Reads StartInterval from plist
- **Last run time** - Stored in `~/.cache/asimov-status.json`
- **Statistics** - Total exclusions, cache entries, scan duration
- **Recent exclusions** - Last 5 entries from cache file

### Logging System

Added comprehensive logging support for debugging and monitoring, especially useful when running as a launchd service.

**Configuration:**

```zsh
ASIMOV_LOG_FILE=~/.local/log/asimov.log
ASIMOV_LOG_FORMAT=text  # or "json"
```

**Text log format:**

```log
[2025-12-03T14:15:23+0100] [INFO] Starting asimov-zsh scan (root: /Users/tobias, opts: cache,mmap)
[2025-12-03T14:15:24+0100] [EXCL] /Users/tobias/work/project/node_modules (45M)
[2025-12-03T14:15:25+0100] [SKIP] /Users/tobias/work/old/node_modules (cached)
[2025-12-03T14:16:08+0100] [INFO] Scan complete: 1234 dirs scanned, 56 excluded, 45s duration
```

**JSON log format:**

```json
{"timestamp":"2025-12-03T14:15:23+0100","level":"INFO","event":"scan_start","message":"Starting asimov-zsh scan","root":"/Users/tobias","optimizations":"cache,mmap"}
{"timestamp":"2025-12-03T14:15:24+0100","level":"EXCL","event":"excluded","message":"Excluded: /Users/tobias/work/project/node_modules","path":"/Users/tobias/work/project/node_modules","size":"45M"}
{"timestamp":"2025-12-03T14:16:08+0100","level":"INFO","event":"scan_complete","message":"Scan complete","dirs_scanned":1234,"dirs_excluded":56,"duration_sec":45}
```

Features:

- **log_info()** - General information messages
- **log_excl()** - Excluded path with size
- **log_skip()** - Skipped path with reason (cached, already_excluded)
- **log_error()** - Error messages (also prints to stderr)
- **log_scan_start()** - Scan start with configuration
- **log_scan_complete()** - Scan completion with statistics

### Color System Refactoring

Refactored the script to use a consistent approach for terminal colors using a global `COLORS` hash-map with NO_COLOR support.

**Implementation:**

```zsh
typeset -A COLORS
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
    COLORS=(
        [reset]='\033[0m'
        [red]='\033[0;31m'
        [green]='\033[0;32m'
        [yellow]='\033[0;33m'
        [blue]='\033[0;34m'
        [magenta]='\033[0;35m'
        [cyan]='\033[0;36m'
        [white]='\033[0;37m'
        [bold]='\033[1m'
    )
else
    # NO_COLOR mode or non-TTY - empty strings
    COLORS=(
        [reset]='' [red]='' [green]='' [yellow]=''
        [blue]='' [magenta]='' [cyan]='' [white]='' [bold]=''
    )
fi

# Usage:
print "${COLORS[cyan]}Finding dependency directories...${COLORS[reset]}"
```

Features:

- **Global COLORS hash-map** - Single source of truth for all colors
- **NO_COLOR support** - Respects <https://no-color.org/> standard
- **TTY detection** - Colors disabled when output is piped/redirected
- **No colors in logs** - Log files are always plain text
- **Consistent usage** - All color codes use `${COLORS[name]}` pattern

### Configuration Refactoring to Associative Array

Refactored the script's configuration approach from individual environment variables to a centralized `ASIMOV_CONFIG` associative array (hash-map) with sensible defaults.

**Implementation**: All configuration is now stored in `ASIMOV_CONFIG` and accessed via `${ASIMOV_CONFIG[key]}`.

```zsh
typeset -A ASIMOV_CONFIG=(
    [root]="${ASIMOV_ROOT:-$HOME}"
    [dry_run]="${ASIMOV_DRY_RUN:-false}"
    [verbose]="${ASIMOV_VERBOSE:-false}"
    [opt_cache]="${ASIMOV_OPT_CACHE:-false}"
    [opt_cache_file]="${ASIMOV_CACHE_FILE:-${HOME}/.cache/asimov-exclusions}"
    [opt_incremental]="${ASIMOV_OPT_INCREMENTAL:-false}"
    [opt_incremental_days]="${ASIMOV_OPT_INCREMENTAL_DAYS:-7}"
    [opt_parallel]="${ASIMOV_OPT_PARALLEL:-false}"
    [opt_parallel_jobs]="${ASIMOV_OPT_PARALLEL_JOBS:-4}"
    [opt_gitignore]="${ASIMOV_OPT_GITIGNORE:-false}"
    [opt_dust]="${ASIMOV_OPT_DUST:-false}"
    [opt_skip_size]="${ASIMOV_OPT_SKIP_SIZE:-false}"
    [opt_mmap]="${ASIMOV_OPT_MMAP:-false}"
    [opt_batch]="${ASIMOV_OPT_BATCH:-false}"
    [opt_batch_size]="${ASIMOV_OPT_BATCH_SIZE:-50}"
)
```

Benefits:

- **Single source of truth** - All configuration in one place
- **Easier to extend** - Add new options without adding new variables
- **Consistent access pattern** - `${ASIMOV_CONFIG[key]}` everywhere
- **Backward compatible** - Still reads from environment variables

### Batch Operations

Batch `tmutil isexcluded` and `du` calls to reduce process spawning overhead.

**Implementation**: `ASIMOV_OPT_BATCH=true` enables batch mode with `ASIMOV_OPT_BATCH_SIZE=50` (default).

```zsh
# Batch exclusion check - check multiple paths in one tmutil call
tmutil isexcluded "${paths[@]}" | while read ...

# Batch size calculation - get sizes for multiple paths at once
du -hs "${paths[@]}" 2>/dev/null
```

Benefits:

- **Reduced process spawning** - One tmutil/du call per batch instead of per path
- **Better I/O patterns** - Batched syscalls are more efficient
- **Configurable batch size** - Tune `ASIMOV_OPT_BATCH_SIZE` for your system

### Use `fd` Instead of `find`

[fd](https://github.com/sharkdp/fd) is a modern replacement for `find` written in Rust:

| Feature   | `find`   | `fd`        |
|-----------|----------|-------------|
| Threading | Single   | Parallel    |
| Regex     | Basic    | Full regex  |
| Speed     | Baseline | 2-5x faster |
| Syntax    | Complex  | Simple      |

**Implementation**:

```zsh
# Build regex pattern for all directory names
fd_pattern="^(node_modules|vendor|\.venv|target|\.gradle)\$"

# Search with parallel traversal
fd --type d --hidden --no-ignore "$fd_pattern" ~/
```

### Use ZSH Builtins

ZSH provides powerful built-in features that eliminate subprocess overhead:

| Operation        | Bash (external) | ZSH (builtin)             |
|------------------|-----------------|---------------------------|
| String split     | `cut -f1`       | `${var%%$'\t'*}`          |
| Pattern match    | `grep -q`       | `[[ $var == *pattern* ]]` |
| Array operations | loops           | `${(j:\|:)array}`         |
| File tests       | `test -e`       | `[[ -e file ]]`           |

**Example**:

```zsh
# Instead of: sizeondisk=$(du -hs "${path}" | cut -f1)
sizeondisk="${$(du -hs "$path")%%$'\t'*}"

# Instead of: grep -Fq '[Excluded]'
[[ "$output" == *"[Excluded]"* ]]
```

### Load ZSH Modules

ZSH modules provide optimized implementations:

```zsh
zmodload zsh/stat      # Fast file stat operations
zmodload zsh/datetime  # Fast date/time operations
zmodload zsh/parameter # Parameter introspection
zmodload zsh/zutil     # Parsing utilities
```

### Precompute Directory/Sentinel Mappings

Instead of building complex find expressions, precompute a hash map:

```zsh
typeset -A SENTINEL_MAP
SENTINEL_MAP[node_modules]="package.json"
SENTINEL_MAP[vendor]="composer.json Gemfile go.mod"
SENTINEL_MAP[.venv]="requirements.txt pyproject.toml"
```

### Caching Exclusion Status

Cache already-excluded paths to avoid repeated `tmutil isexcluded` calls.

**Implementation**: `ASIMOV_OPT_CACHE=true` enables file-based caching at `~/.cache/asimov-exclusions`.

```zsh
# Store exclusions in a file
CACHE_FILE=~/.cache/asimov-exclusions

# Check cache before calling tmutil
if grep -qF "$path" "$CACHE_FILE"; then
    continue
fi
```

### Incremental Scanning

Only scan directories modified since last run.

**Implementation**: `ASIMOV_OPT_INCREMENTAL=true` with `ASIMOV_OPT_INCREMENTAL_DAYS=7` (default).

```zsh
# Use fd with --changed-within
fd --changed-within 1day ...
```

### Parallel tmutil Calls

Use ZSH's built-in job control for parallel exclusions.

**Implementation**: `ASIMOV_OPT_PARALLEL=true` with `ASIMOV_OPT_PARALLEL_JOBS=4` (default).

```zsh
# Background multiple exclusions
for path in "${paths[@]}"; do
    tmutil addexclusion "$path" &
done
wait
```

### Use `.gitignore` Awareness

`fd` respects `.gitignore` by default, which can speed up searches.

**Implementation**: `ASIMOV_OPT_GITIGNORE=true` removes `--no-ignore` flag from fd.

```zsh
fd --type d "$pattern" ~/  # Automatically ignores .git paths
```

### Memory-Mapped File Operations (In-Memory Hash)

For very large filesystems with thousands of exclusions, reading/writing the cache file on every operation can become a bottleneck.

**Implementation**: `ASIMOV_OPT_MMAP=true` loads cache into `MMAP_CACHE` associative array for O(1) lookups and batches writes at the end via `flush_mmap_cache()`.

1. **Mapping the cache file directly into memory** - The OS handles paging efficiently
2. **Avoiding repeated file I/O** - Changes are written to memory first, then synced
3. **Faster lookups** - The entire exclusion list is in memory

#### ZSH Implementation

```zsh
# Load entire cache into an associative array at startup
typeset -A EXCLUSION_CACHE
if [[ -f "$ASIMOV_CACHE_FILE" ]]; then
    while IFS= read -r line; do
        EXCLUSION_CACHE[$line]=1
    done < "$ASIMOV_CACHE_FILE"
fi

# Fast O(1) lookup instead of grep
is_cached() {
    [[ -n "${EXCLUSION_CACHE[$1]}" ]]
}

# Batch write at end instead of appending each time
typeset -a NEW_EXCLUSIONS=()
add_to_cache() {
    NEW_EXCLUSIONS+=("$1")
    EXCLUSION_CACHE[$1]=1
}

# Write all new exclusions at once when done
flush_cache() {
    if (( ${#NEW_EXCLUSIONS[@]} > 0 )); then
        printf '%s\n' "${NEW_EXCLUSIONS[@]}" >> "$ASIMOV_CACHE_FILE"
    fi
}
```

#### When to Use

- **Home directories with 10,000+ files** - Significant I/O reduction
- **Network-mounted filesystems** - Reduces network round-trips
- **SSDs with limited write cycles** - Batches writes together

#### Performance Impact

| Cache Method   | Lookup Time | Memory Usage | Write Latency |
|----------------|-------------|--------------|---------------|
| grep file      | O(n)        | Low          | Per-operation |
| Hash in memory | O(1)        | Medium       | Batch at end  |
| SQLite         | O(log n)    | Low          | Transactional |

### Alternative to `du` (dust)

Replace `du` with `dust` which is faster and written in Rust.

**Implementation**: `ASIMOV_OPT_DUST=true` uses dust for size calculation. Additionally, `ASIMOV_OPT_SKIP_SIZE=true` skips size calculation entirely for maximum speed.

## Reference Documentation

### dust Help

```bash
❯ dust --help
Like du but more intuitive

Usage: dust [OPTIONS] [PATH]...

Arguments:
  [PATH]...
          Input files or directories

Options:
  -d, --depth <DEPTH>
          Depth to show

  -T, --threads <THREADS>
          Number of threads to use

      --config <FILE>
          Specify a config file to use

  -n, --number-of-lines <NUMBER>
          Number of lines of output to show. (Default is terminal_height - 10)

  -p, --full-paths
          Subdirectories will not have their path shortened

  -X, --ignore-directory <PATH>
          Exclude any file or directory with this path

  -I, --ignore-all-in-file <FILE>
          Exclude any file or directory with a regex matching that listed in this file, the file entries will be added to the ignore regexs provided by --invert_filter

  -L, --dereference-links
          dereference sym links - Treat sym links as directories and go into them

  -x, --limit-filesystem
          Only count the files and directories on the same filesystem as the supplied directory

  -s, --apparent-size
          Use file length instead of blocks

  -r, --reverse
          Print tree upside down (biggest highest)

  -c, --no-colors
          No colors will be printed (Useful for commands like: watch)

  -C, --force-colors
          Force colors print

  -b, --no-percent-bars
          No percent bars or percentages will be displayed

  -B, --bars-on-right
          percent bars moved to right side of screen

  -z, --min-size <MIN_SIZE>
          Minimum size file to include in output

  -R, --screen-reader
          For screen readers. Removes bars. Adds new column: depth level (May want to use -p too for full path)

      --skip-total
          No total row will be displayed

  -f, --filecount
          Directory 'size' is number of child files instead of disk size

  -i, --ignore-hidden
          Do not display hidden files

  -v, --invert-filter <REGEX>
          Exclude filepaths matching this regex. To ignore png files type: -v "\.png$"

  -e, --filter <REGEX>
          Only include filepaths matching this regex. For png files type: -e "\.png$"

  -t, --file-types
          show only these file types

  -w, --terminal-width <WIDTH>
          Specify width of output overriding the auto detection of terminal width

  -P, --no-progress
          Disable the progress indication

      --print-errors
          Print path with errors

  -D, --only-dir
          Only directories will be displayed

  -F, --only-file
          Only files will be displayed. (Finds your largest files)

  -o, --output-format <FORMAT>
          Changes output display size. si will print sizes in powers of 1000. b k m g t kb mb gb tb will print the whole tree in that size

          Possible values:
          - si: SI prefix (powers of 1000)
          - b:  byte (B)
          - k:  kibibyte (KiB)
          - m:  mebibyte (MiB)
          - g:  gibibyte (GiB)
          - t:  tebibyte (TiB)
          - kb: kilobyte (kB)
          - mb: megabyte (MB)
          - gb: gigabyte (GB)
          - tb: terabyte (TB)

  -S, --stack-size <STACK_SIZE>
          Specify memory to use as stack size - use if you see: 'fatal runtime error: stack overflow' (default low memory=1048576, high memory=1073741824)

  -j, --output-json
          Output the directory tree as json to the current directory

  -M, --mtime <MTIME>
          +/-n matches files modified more/less than n days ago , and n matches files modified exactly n days ago, days are rounded down.That is +n => (−∞, curr−(n+1)), n => [curr−(n+1), curr−n), and -n => (𝑐𝑢𝑟𝑟−𝑛, +∞)

  -A, --atime <ATIME>
          just like -mtime, but based on file access time

  -y, --ctime <CTIME>
          just like -mtime, but based on file change time

      --files0-from <FILES0_FROM>
          run dust on NUL-terminated file names specified in file; if argument is -, then read names from standard input

      --collapse <COLLAPSE>
          Keep these directories collapsed

  -m, --filetime <FILETIME>
          Directory 'size' is max filetime of child files instead of disk size. while a/c/m for last accessed/changed/modified time

          Possible values:
          - a: last accessed time
          - c: last changed time
          - m: last modified time

  -h, --help
          Print help (see a summary with '-h')

  -V, --version
          Print version
```

## Compatibility Notes

| Feature     | macOS       | Linux       |
|-------------|-------------|-------------|
| `tmutil`    | ✅           | ❌           |
| `fd`        | ✅ (brew)    | ✅ (apt/dnf) |
| ZSH         | ✅ (default) | ✅ (install) |
| ZSH modules | ✅           | ✅           |

## Conclusion

The primary performance improvements come from:

1. **Switching from `find` to `fd`** (2-5x speedup in directory traversal)
2. **Using ZSH builtins** (eliminates subprocess overhead)
3. **Precomputed mappings** (reduces runtime computation)

The `asimov-zsh` implementation demonstrates these optimizations and can be benchmarked using the provided `benchmark-asimov.zsh` script.

## Retrieving Current Time Machine Exclusions

Time Machine stores exclusion information in two ways:

### 1. Extended Attributes (xattr) - Per-File Exclusions

When you use `tmutil addexclusion` without the `-p` flag, it sets an extended attribute on the file/directory:

```bash
# Check if a specific path has the exclusion xattr
xattr -l /path/to/directory
# Output: com.apple.metadata:com_apple_backup_excludeItem: bplist00_com.apple.backupd

# Check exclusion status with tmutil
tmutil isexcluded /path/to/directory
# Output: [Excluded]  /path/to/directory
```

### 2. Fixed-Path Exclusions (-p flag)

Using `tmutil addexclusion -p` adds the path to the system plist:

```bash
# View fixed-path exclusions
defaults read /Library/Preferences/com.apple.TimeMachine.plist SkipPaths
```

### 3. Listing ALL Current Exclusions with `mdfind`

The most comprehensive way to list all excluded paths is using Spotlight's `mdfind`:

```bash
# List all Time Machine exclusions (requires sudo for full results)
sudo mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'"

# Count total exclusions
sudo mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'" | wc -l

# Filter by directory pattern
sudo mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'" | grep "node_modules"

# Exclusions in a specific directory
sudo mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'" | grep "work-dev"
```

### 4. Using the Exclusion List for Cache Initialization

Instead of building a cache from scratch, we can initialize it with current exclusions:

```zsh
# Export current exclusions to cache file
sudo mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'" > ~/.cache/asimov-exclusions

# Then asimov-zsh with MMAP will load these for O(1) lookups
ASIMOV_OPT_CACHE=true ASIMOV_OPT_MMAP=true ./asimov-zsh
```

### 5. Removing Exclusions

```bash
# Remove exclusion from a specific path
tmutil removeexclusion /path/to/directory

# Verify it's no longer excluded
tmutil isexcluded /path/to/directory
# Output: [Included]  /path/to/directory
```

### Performance Comparison: tmutil vs mdfind

| Method              | Speed         | Scope          | Requires sudo           |
|---------------------|---------------|----------------|-------------------------|
| `tmutil isexcluded` | Fast (single) | One path       | No                      |
| `mdfind` query      | Fast (all)    | All exclusions | Yes (for complete list) |
| `xattr -l`          | Fast (single) | One path       | No                      |
| Loop with tmutil    | Slow          | Multiple paths | No                      |

**Recommendation**: Use `mdfind` to export all exclusions once, then use the cache for subsequent runs.

### Exclusion Types Summary

| Type           | Command                       | Stored In                  | Survives Move |
|----------------|-------------------------------|----------------------------|---------------|
| Sticky (xattr) | `tmutil addexclusion path`    | Extended attribute on file | Yes           |
| Fixed-path     | `tmutil addexclusion -p path` | System plist               | No            |
| Volume         | System default                | TimeMachine plist          | N/A           |

The default `tmutil addexclusion` (without `-p`) is preferred for development directories because the exclusion "sticks" to the directory even if moved.

## Files Created

- `asimov-zsh` - Optimized ZSH implementation with fd
- `benchmark-asimov.zsh` - Hyperfine benchmark script
- `how-to-improve-the-performance-of-asimov.md` - This document

## Running the Benchmark

```bash
cd asimov/
./benchmark-asimov.zsh --runs 10 --warmup 3 --output ./benchmark-results
```

The benchmark creates a test environment with simulated project structures and compares:

- Original: `bash` + `find`
- Optimized: `zsh` + `fd`

Results are exported to JSON and Markdown formats for analysis.
