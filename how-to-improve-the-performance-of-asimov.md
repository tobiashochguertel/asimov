# How to Improve the Performance of Asimov

This document outlines strategies and optimizations to improve the performance of the `asimov` script, which excludes development dependency directories from Apple Time Machine backups.

## Executive Summary

The original `asimov` script uses `bash` with `find` for directory traversal. By switching to `zsh` with `fd`, we can achieve significant performance improvements due to:

1. **Parallel directory traversal** with `fd`
2. **Native ZSH string operations** instead of external tools
3. **Compiled Rust performance** of `fd` vs interpreted shell in `find`

## Performance Bottlenecks in Original Implementation

### 1. Sequential Directory Traversal with `find`

The original script uses GNU `find` which traverses directories sequentially:

```bash
find "${ASIMOV_ROOT}" \( "${find_parameters_skip[@]}" \) \( -false "${find_parameters_vendor[@]}" \)
```

**Issue**: `find` is single-threaded and processes directories one at a time.

### 2. External Tool Invocations

The script uses external tools for simple operations:

```bash
sizeondisk=$(du -hs "${path}" | cut -f1)  # External cut
grep -Fq '[Excluded]'                     # External grep
```

**Issue**: Each external tool invocation creates a new subprocess, adding overhead.

### 3. Complex Find Expression

The script builds a complex `find` expression with many `-or` conditions:

```bash
find_parameters_vendor+=( -or \( \
    -type d \
    -name "${_exclude_name}" \
    -execdir test -e "${_sibling_sentinel_name}" \; \
    ...
\) )
```

**Issue**: Each condition is evaluated sequentially for every directory.

## Optimization Strategies

### Strategy 1: Use `fd` Instead of `find`

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

### Strategy 2: Use ZSH Builtins

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

### Strategy 3: Load ZSH Modules

ZSH modules provide optimized implementations:

```zsh
zmodload zsh/stat      # Fast file stat operations
zmodload zsh/datetime  # Fast date/time operations
zmodload zsh/parameter # Parameter introspection
zmodload zsh/zutil     # Parsing utilities
```

### Strategy 4: Precompute Directory/Sentinel Mappings

Instead of building complex find expressions, precompute a hash map:

```zsh
typeset -A SENTINEL_MAP
SENTINEL_MAP[node_modules]="package.json"
SENTINEL_MAP[vendor]="composer.json Gemfile go.mod"
SENTINEL_MAP[.venv]="requirements.txt pyproject.toml"
```

### Strategy 5: Batch Operations

Group similar operations to reduce syscall overhead:

```zsh
# Batch exclusion check
tmutil isexcluded "${paths[@]}" | while read ...

# Parallel size calculation (if needed)
du -hs "${paths[@]}" 2>/dev/null
```

## Alternative Tools Comparison

### `fd` vs `find` vs `rg` vs `ack`

| Tool           | Use Case         | Speed | Best For                |
|----------------|------------------|-------|-------------------------|
| `fd`           | File/dir finding | ⭐⭐⭐⭐⭐ | Directory traversal     |
| `find`         | File/dir finding | ⭐⭐⭐   | POSIX compatibility     |
| `rg` (ripgrep) | Content search   | ⭐⭐⭐⭐⭐ | Searching file contents |
| `ack`          | Content search   | ⭐⭐⭐   | Perl regex support      |

**Recommendation**: Use `fd` for directory finding (our use case). `rg` and `ack` are content search tools and not optimal for finding directories by name.

## Implementation: `asimov-zsh`

The optimized implementation (`asimov-zsh`) includes:

1. **ZSH shebang** with strict mode:

   ```zsh
   #!/usr/bin/env zsh
   setopt ERR_EXIT NO_UNSET PIPE_FAIL
   ```

2. **Module loading**:

   ```zsh
   zmodload zsh/stat
   zmodload zsh/datetime
   ```

3. **`fd` for parallel search**:

   ```zsh
   fd --type d --hidden --no-ignore "$fd_pattern" ~/
   ```

4. **Native string operations**:

   ```zsh
   local dir_name="${pair%% *}"
   local sentinel="${pair#* }"
   ```

## Benchmarking

Use the provided `benchmark-asimov.zsh` script to compare implementations:

```bash
./benchmark-asimov.zsh --runs 10 --warmup 3
```

### Important Notes on Performance

**Small vs Large Filesystems:**

- On **small directory trees** (few hundred directories), `find` may actually be faster due to `fd`'s startup overhead
- On **large filesystems** (thousands of directories), `fd`'s parallel traversal provides significant speedup
- The crossover point depends on disk speed, CPU cores, and directory structure

**Initial Benchmark Results (Small Test Environment):**

| Command              |    Mean [ms] | Relative |
|:---------------------|-------------:|---------:|
| bash+find (original) | 250.1 ± 34.0 |     1.00 |
| zsh+fd (optimized)   | 723.6 ± 36.0 |     2.89 |

The small test environment (~200 files) shows `find` winning due to `fd`'s Rust runtime initialization overhead.

**Real-World Benchmark Results (~/work-dev - Large Development Directory):**

| Command              |       Mean [s] | Relative |
|:---------------------|---------------:|---------:|
| bash+find (original) | 64.112 ± 1.393 |     2.44 |
| zsh+fd (optimized)   | 26.222 ± 0.134 | **1.00** |

On a real development directory with many projects and deep `node_modules` trees, **`fd` is 2.44x faster than `find`**!

**Real-World Performance (Large Home Directory):**

For actual home directories with many projects, `fd` typically outperforms `find` by 2-5x because:

- Parallel directory traversal uses all CPU cores
- Smart ignore patterns skip unnecessary traversal
- Rust's optimized I/O operations

**Recommendation:** Run benchmarks on your actual filesystem to determine which performs better for your use case.

## Additional Optimization Ideas

### 1. Caching Exclusion Status

Cache already-excluded paths to avoid repeated `tmutil isexcluded` calls:

```zsh
# Store exclusions in a file
CACHE_FILE=~/.cache/asimov-exclusions

# Check cache before calling tmutil
if grep -qF "$path" "$CACHE_FILE"; then
    continue
fi
```

### 2. Incremental Scanning

Only scan directories modified since last run:

```zsh
# Use find with -newer
fd --changed-within 1day ...
```

### 3. Parallel tmutil Calls

Use GNU Parallel or ZSH's built-in job control:

```zsh
# Background multiple exclusions
for path in "${paths[@]}"; do
    tmutil addexclusion "$path" &
done
wait
```

### 4. Use `.gitignore` Awareness

`fd` respects `.gitignore` by default, which can speed up searches:

```zsh
fd --type d "$pattern" ~/  # Automatically ignores .git paths
```

### 5. Memory-Mapped File Operations

For very large filesystems with thousands of exclusions, reading/writing the cache file on every operation can become a bottleneck. Memory-mapped I/O can help by:

1. **Mapping the cache file directly into memory** - The OS handles paging efficiently
2. **Avoiding repeated file I/O** - Changes are written to memory first, then synced
3. **Faster lookups** - The entire exclusion list is in memory

#### ZSH Implementation Concept

ZSH doesn't have native mmap support, but we can achieve similar benefits with:

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

#### Alternative: SQLite Cache

For very large exclusion lists (100,000+), consider using SQLite:

```zsh
# Using sqlite3 CLI (available on macOS by default)
sqlite3 ~/.cache/asimov.db "CREATE TABLE IF NOT EXISTS exclusions (path TEXT PRIMARY KEY)"
sqlite3 ~/.cache/asimov.db "SELECT 1 FROM exclusions WHERE path='$dir_path' LIMIT 1"
sqlite3 ~/.cache/asimov.db "INSERT OR IGNORE INTO exclusions VALUES ('$dir_path')"
```

Benefits:

- **Indexed lookups** - O(log n) instead of O(n)
- **ACID transactions** - Safe concurrent access
- **Compression** - SQLite compresses data automatically

#### Performance Impact

| Cache Method   | Lookup Time | Memory Usage | Write Latency |
|----------------|-------------|--------------|---------------|
| grep file      | O(n)        | Low          | Per-operation |
| Hash in memory | O(1)        | Medium       | Batch at end  |
| SQLite         | O(log n)    | Low          | Transactional |

**Recommendation**: For most users, the in-memory hash approach (implemented as `ASIMOV_OPT_CACHE`) is sufficient. SQLite is only needed for enterprise-scale deployments.

### 6. Alternative to `du`

We might can replace `du` with `dust` which is faster and written in Rust too:

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
