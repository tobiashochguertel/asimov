# Asimov

> **Fork Notice:** This is a fork of [stevegrunwell/asimov](https://github.com/stevegrunwell/asimov), originally created by [Steve Grunwell](https://stevegrunwell.com). All credit for the original work goes to the original author. This fork is maintained by [Tobias Hochguertel](https://github.com/tobiashochguertel).

![Requires macOS 10.13 (High Sierra) or newer](https://img.shields.io/badge/macOS-10.13%20or%20higher-blue)
[![MIT license](https://img.shields.io/badge/license-MIT-green)](LICENSE.txt)

> Those people who think they know everything are a great annoyance to those of us who do.<br>— Isaac Asimov

For macOS users, [Time Machine](https://support.apple.com/HT201250) is a no-frills, set-it-and-forget-it solution for on-site backups. Plug in an external hard drive (or configure a network storage drive), and your Mac's files are backed up.

For the average consumer, Time Machine is an excellent choice, especially considering many Mac owners may _only_ have Time Machine as a backup strategy. For developers, however, Time Machine presents a problem: **how do I keep project dependencies from taking up space on my Time Machine drive?**

Asimov aims to solve that problem, scanning your filesystem for known dependency directories (e.g. `node_modules/` living adjacent to a `package.json` file) and excluding them from Time Machine backups. After all, why eat up space on your backup drive for something you could easily restore via `npm install`?

## Two Versions Available

This fork provides two versions of Asimov:

| Version       | File         | Shell | Performance     | Dependencies                         |
|---------------|--------------|-------|-----------------|--------------------------------------|
| **Original**  | `asimov`     | Bash  | Good            | None (built-in tools)                |
| **Optimized** | `asimov-zsh` | ZSH   | **2-3x faster** | `fd` (install via `brew install fd`) |

### Why an Optimized ZSH Version?

The optimized version (`asimov-zsh`) offers significant performance improvements:

- **Parallel directory traversal** using `fd` (Rust-based, multi-threaded)
- **In-memory caching** for O(1) exclusion lookups
- **Native ZSH operations** instead of spawning subprocesses
- **Configurable optimizations** via environment variables

See [how-to-improve-the-performance-of-asimov.md](how-to-improve-the-performance-of-asimov.md) for detailed benchmarks and optimization strategies.

## Installation

### Prerequisites

For the optimized ZSH version (recommended):

```sh
# Install fd (required for asimov-zsh)
brew install fd

# Optional: Install tmux for background migration scan
brew install tmux
```

### Quick Install (Recommended: ZSH Version)

```sh
# Clone the repository
git clone https://github.com/tobiashochguertel/asimov.git ~/asimov
cd ~/asimov

# Install the optimized ZSH version with all optimizations
./install.sh --zsh
```

### Migration from Homebrew Asimov

If you previously installed asimov via Homebrew (`brew install asimov`), use our migration script:

```sh
# Clone the repository
git clone https://github.com/tobiashochguertel/asimov.git ~/asimov
cd ~/asimov

# Uninstall Homebrew version first
brew uninstall asimov

# Run migration (backs up exclusions, initializes cache, starts full scan in tmux)
./migrate-to-asimov-zsh.zsh
```

The migration script will:

- Backup your current Time Machine exclusions
- Initialize the cache from existing exclusions
- Create a symlink to `/usr/local/bin/asimov`
- Start a full home directory scan in a tmux session
- Load the daily daemon

See [Migration Guide](docs/MIGRATION-GUIDE.md) for detailed instructions.

### Alternative: Original Bash Version

If you prefer the original bash version (no additional dependencies):

```sh
git clone https://github.com/tobiashochguertel/asimov.git ~/asimov
cd ~/asimov
./install.sh
```

### What the Install Script Does

- Symlinks asimov to `/usr/local/bin/asimov`
- Loads a launchd daemon to run asimov daily
- Runs asimov for the first time

## Upgrading

If you already have asimov-zsh installed and want to upgrade to the latest version:

### Quick Upgrade

```sh
# Navigate to your asimov directory
cd ~/asimov  # or wherever you cloned it

# Pull the latest changes
git pull

# Run the upgrade
./install.sh --upgrade
```

The upgrade command will:

- Stop the running daemon
- Update the binary at `/usr/local/bin/asimov`
- Update the daemon configuration with new optimizations enabled
- **Initialize SQLite cache from existing exclusions**
- Restart the daemon

Everything is automatic - no manual steps required.

### Verify the Upgrade

```sh
# Check the service status
ASIMOV_STATUS=true asimov

# View recent logs
tail -f ~/.local/log/asimov.log
```

### What's New After Upgrade

The new plist configuration enables these features by default:

| Feature        | Description                                    |
|----------------|------------------------------------------------|
| SQLite Cache   | O(log n) indexed lookups for 100,000+ entries  |
| JSON Logging   | Structured logging to `~/.local/log/asimov.log`|
| Batch Mode     | Reduced process spawning overhead              |
| Skip Size      | Faster scans by skipping size calculation      |

## Usage

### Basic Usage

```sh
# Run asimov (whichever version is installed)
asimov
```

### Optimized ZSH Version Options

The ZSH version supports many configuration options via environment variables:

```sh
# Scan a specific directory
ASIMOV_ROOT=~/work-dev asimov

# Dry run (show what would be excluded without actually excluding)
ASIMOV_DRY_RUN=true asimov

# Verbose output
ASIMOV_VERBOSE=true asimov

# List current Time Machine exclusions
ASIMOV_LIST_EXCLUSIONS=true asimov

# Initialize cache from current exclusions (faster subsequent runs)
ASIMOV_INIT_CACHE=true asimov
```

### Performance Optimizations (ZSH Version)

Enable optimizations for faster execution:

```sh
# Enable caching with SQLite + batch operations + skip size calculation
ASIMOV_OPT_CACHE=true \
ASIMOV_OPT_SQLITE=true \
ASIMOV_OPT_BATCH=true \
ASIMOV_OPT_SKIP_SIZE=true \
asimov
```

| Optimization  | Environment Variable          | Description                                      |
|---------------|-------------------------------|--------------------------------------------------|
| Caching       | `ASIMOV_OPT_CACHE=true`       | Enable exclusion status caching                  |
| SQLite        | `ASIMOV_OPT_SQLITE=true`      | Use SQLite for O(log n) indexed lookups          |
| Memory-mapped | `ASIMOV_OPT_MMAP=true`        | Load file cache into memory for O(1) lookups     |
| Batch         | `ASIMOV_OPT_BATCH=true`       | Batch tmutil and du operations                   |
| Skip Size     | `ASIMOV_OPT_SKIP_SIZE=true`   | Skip directory size calculation                  |
| Incremental   | `ASIMOV_OPT_INCREMENTAL=true` | Only scan recently modified directories          |
| Parallel      | `ASIMOV_OPT_PARALLEL=true`    | Run tmutil calls in parallel                     |
| Gitignore     | `ASIMOV_OPT_GITIGNORE=true`   | Use fd's gitignore awareness                     |
| Dust          | `ASIMOV_OPT_DUST=true`        | Use dust instead of du for size                  |

**Recommended for production:** SQLite + Batch + Skip Size (default in launchd plist)

### Service Status

Check the status of the asimov launchd service:

```sh
# Show service status, statistics, and recent exclusions
ASIMOV_STATUS=true asimov
```

### Logging

Enable logging for debugging or monitoring:

```sh
# Log to file (text format)
ASIMOV_LOG_FILE=~/.local/log/asimov.log asimov

# Log in JSON format
ASIMOV_LOG_FILE=~/.local/log/asimov.json ASIMOV_LOG_FORMAT=json asimov
```

> **Note:** The script automatically expands `~` to `$HOME` in all path-related environment variables. This is necessary because launchd does not expand `~` or `$HOME` in plist environment variables.

### Color Output

Asimov supports the [NO_COLOR](https://no-color.org/) standard:

```sh
# Disable colors
NO_COLOR=1 asimov

# Colors are also disabled automatically when output is piped
asimov | cat
```

## How it works

At its essence, Asimov is a simple wrapper around Apple's `tmutil` program, which provides more granular control over Time Machine.

Asimov finds recognized dependency directories, verifies that the corresponding dependency file exists and, if so, tells Time Machine not to worry about backing up the dependency directory.

Don't worry about running it multiple times, either. Asimov is smart enough to see if a directory has already been marked for exclusion.

### Supported Dependency Directories

Asimov recognizes these dependency patterns:

| Directory          | Sentinel File      | Language/Tool   |
|--------------------|--------------------|-----------------|
| `node_modules`     | `package.json`     | Node.js         |
| `vendor`           | `composer.json`    | PHP (Composer)  |
| `vendor`           | `Gemfile`          | Ruby (Bundler)  |
| `vendor`           | `go.mod`           | Go              |
| `.venv`, `venv`    | `requirements.txt` | Python          |
| `target`           | `Cargo.toml`       | Rust            |
| `target`           | `pom.xml`          | Java (Maven)    |
| `.gradle`, `build` | `build.gradle`     | Java (Gradle)   |
| `Pods`             | `Podfile`          | iOS (CocoaPods) |
| `deps`, `.build`   | `mix.exs`          | Elixir          |
| And more...        |                    |                 |

### Retrieving Excluded Files

If you'd like to see all of the directories and files that have been excluded from Time Machine, you can do so by running:

```bash
# Using mdfind (most comprehensive)
sudo mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'"

# Using the ZSH version's list mode
ASIMOV_LIST_EXCLUSIONS=true ASIMOV_VERBOSE=true asimov

# Check a specific path
tmutil isexcluded /path/to/directory
```

If a directory has been excluded from backups in error, you can remove the exclusion using `tmutil`:

```bash
tmutil removeexclusion /path/to/directory
```

## Benchmarking

The repository includes a benchmark script to compare performance:

```sh
# Basic benchmark (bash vs zsh)
./benchmark-asimov.zsh --mode basic --root ~/work-dev --runs 5

# Benchmark optimization combinations
./benchmark-asimov.zsh --mode optimizations --root ~/work-dev --runs 5

# Run all benchmarks
./benchmark-asimov.zsh --mode all --root ~/work-dev --runs 5
```

## Documentation

- **[User Guide](docs/USER-GUIDE.md)** - How to use and maintain asimov over time
- **[Migration Guide](docs/MIGRATION-GUIDE.md)** - Migrating from original asimov to the ZSH version
- **[Performance Guide](how-to-improve-the-performance-of-asimov.md)** - Detailed optimization strategies and benchmarks

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE.txt](LICENSE.txt) for details.
