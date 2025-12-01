#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 4; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

# Benchmark script for comparing asimov implementations and optimization combinations
#
# This script uses hyperfine to benchmark:
# 1. Original bash+find implementation
# 2. Optimized zsh+fd implementation
# 3. Various optimization combinations
#
# Usage: ./benchmark-asimov.zsh [options]
#   --runs N           Number of benchmark runs (default: 10)
#   --warmup N         Number of warmup runs (default: 3)
#   --output DIR       Output directory for reports
#   --root DIR         Directory to benchmark
#   --mode MODE        Benchmark mode: basic, optimizations, all (default: basic)
#   --dry-run          Only show what would be searched

set -euo pipefail

# Configuration
SCRIPT_DIR="${0:A:h}"
RUNS="${BENCHMARK_RUNS:-10}"
WARMUP="${BENCHMARK_WARMUP:-3}"
OUTPUT_DIR="${BENCHMARK_OUTPUT:-${SCRIPT_DIR}/benchmark-results}"
DRY_RUN=false
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BENCHMARK_MODE="${BENCHMARK_MODE:-basic}"

# Test root directory - use BENCHMARK_ROOT or create temp dir
USE_TEMP_DIR=true
TEST_ROOT="${BENCHMARK_ROOT:-}"
if [[ -n "$TEST_ROOT" ]]; then
    USE_TEMP_DIR=false
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --runs)
            RUNS="$2"
            shift 2
            ;;
        --warmup)
            WARMUP="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --root)
            TEST_ROOT="$2"
            USE_TEMP_DIR=false
            shift 2
            ;;
        --mode)
            BENCHMARK_MODE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            print "Usage: $0 [options]"
            print ""
            print "Options:"
            print "  --runs N       Number of benchmark runs (default: 10, env: BENCHMARK_RUNS)"
            print "  --warmup N     Number of warmup runs (default: 3, env: BENCHMARK_WARMUP)"
            print "  --output DIR   Output directory for reports (env: BENCHMARK_OUTPUT)"
            print "  --root DIR     Directory to benchmark (default: temp dir, env: BENCHMARK_ROOT)"
            print "  --mode MODE    Benchmark mode (env: BENCHMARK_MODE)"
            print "                   basic: find vs fd only"
            print "                   optimizations: test each optimization individually"
            print "                   all: test all combinations"
            print "  --dry-run      Show what would be searched without excluding"
            print "  -h, --help     Show this help message"
            print ""
            print "Environment Variables:"
            print "  BENCHMARK_ROOT    Directory to scan (uses real projects if set)"
            print "  BENCHMARK_RUNS    Number of benchmark runs"
            print "  BENCHMARK_WARMUP  Number of warmup runs"
            print "  BENCHMARK_OUTPUT  Output directory for reports"
            print "  BENCHMARK_MODE    Benchmark mode (basic, optimizations, all)"
            print ""
            print "Optimization Flags (for asimov-zsh):"
            print "  ASIMOV_OPT_CACHE       Enable exclusion caching (OPT 1)"
            print "  ASIMOV_OPT_INCREMENTAL Enable incremental scanning (OPT 2)"
            print "  ASIMOV_OPT_PARALLEL    Enable parallel tmutil calls (OPT 3)"
            print "  ASIMOV_OPT_GITIGNORE   Use gitignore awareness (OPT 4)"
            print "  ASIMOV_OPT_MMAP        Use in-memory hash cache (OPT 5)"
            print "  ASIMOV_OPT_DUST        Use dust instead of du (OPT 6)"
            print "  ASIMOV_OPT_SKIP_SIZE   Skip size calculation (OPT 6)"
            exit 0
            ;;
        *)
            print "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Verify dependencies
check_dependencies() {
    local missing=()
    
    command -v hyperfine &>/dev/null || missing+=(hyperfine)
    command -v fd &>/dev/null || missing+=(fd)
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print "Error: Missing dependencies: ${missing[*]}"
        print "Install with: brew install ${missing[*]}"
        exit 1
    fi
}

# Create a test environment to benchmark against
# This creates a temporary directory structure that mimics a real development setup
create_test_environment() {
    local test_root="$1"
    
    print "Creating test environment in $test_root..."
    
    mkdir -p "$test_root"
    
    # Create various project structures
    local projects=(
        "project-node/node_modules"
        "project-node/package.json"
        "project-python/.venv"
        "project-python/requirements.txt"
        "project-rust/target"
        "project-rust/Cargo.toml"
        "project-php/vendor"
        "project-php/composer.json"
        "project-gradle/.gradle"
        "project-gradle/build.gradle"
        "nested/deep/project/node_modules"
        "nested/deep/project/package.json"
        "another/path/to/.venv"
        "another/path/to/pyproject.toml"
    )
    
    for item in "${projects[@]}"; do
        local item_path="$test_root/$item"
        if [[ "$item" == */* && ! "$item" == *.* ]]; then
            mkdir -p "$item_path"
        else
            mkdir -p "${item_path:h}"
            touch "$item_path"
        fi
    done
    
    # Create some dummy files in node_modules to simulate real size
    for i in {1..100}; do
        mkdir -p "$test_root/project-node/node_modules/package-$i"
        dd if=/dev/zero of="$test_root/project-node/node_modules/package-$i/index.js" bs=1024 count=10 2>/dev/null
    done
}

# Clean up test environment
cleanup_test_environment() {
    local test_root="$1"
    if [[ -d "$test_root" ]]; then
        rm -rf "$test_root"
    fi
}

# Run the benchmark
run_benchmark() {
    local asimov_bash="${SCRIPT_DIR}/asimov"
    local asimov_zsh="${SCRIPT_DIR}/asimov-zsh"
    
    # Verify scripts exist
    if [[ ! -f "$asimov_bash" ]]; then
        print "Error: Original asimov script not found at $asimov_bash"
        exit 1
    fi
    
    if [[ ! -f "$asimov_zsh" ]]; then
        print "Error: Optimized asimov-zsh script not found at $asimov_zsh"
        exit 1
    fi
    
    # Determine test root (for backward compatibility when called directly)
    local test_root
    local test_type
    if $USE_TEMP_DIR; then
        test_root=$(mktemp -d)
        trap "cleanup_test_environment '$test_root'" EXIT
        create_test_environment "$test_root"
        test_type="synthetic (temp directory)"
    else
        test_root="$TEST_ROOT"
        if [[ ! -d "$test_root" ]]; then
            print "Error: Specified root directory does not exist: $test_root"
            exit 1
        fi
        test_type="real filesystem"
    fi
    
    print "\n\033[0;36mBenchmarking asimov implementations...\033[0m\n"
    print "Test environment: $test_root ($test_type)"
    print "Output directory: $OUTPUT_DIR"
    print "Runs: $RUNS, Warmup: $WARMUP"
    print "Mode: $BENCHMARK_MODE"
    print ""
    
    # Create wrapper scripts that use test environment
    local bash_wrapper=$(mktemp)
    local zsh_wrapper=$(mktemp)
    
    # Note: We're benchmarking the 'find' vs 'fd' portion only
    # by measuring just the directory search, not the tmutil calls
    
    cat > "$bash_wrapper" << EOF
#!/usr/bin/env bash
# Benchmark only the find portion (without tmutil which requires sudo)
find "$test_root" -type d \( -name "node_modules" -o -name ".venv" -o -name "target" -o -name "vendor" -o -name ".gradle" \) -prune -print 2>/dev/null || true
EOF
    
    cat > "$zsh_wrapper" << EOF
#!/usr/bin/env zsh
# Benchmark only the fd portion
fd --type d --hidden --no-ignore '^(node_modules|\\.venv|target|vendor|\\.gradle)\$' '$test_root' 2>/dev/null || true
EOF
    
    chmod +x "$bash_wrapper" "$zsh_wrapper"
    
    # Run hyperfine benchmark
    local report_json="$OUTPUT_DIR/benchmark_${TIMESTAMP}.json"
    local report_md="$OUTPUT_DIR/benchmark_${TIMESTAMP}.md"
    
    hyperfine \
        --warmup "$WARMUP" \
        --runs "$RUNS" \
        --export-json "$report_json" \
        --export-markdown "$report_md" \
        --command-name "bash+find (original)" "$bash_wrapper" \
        --command-name "zsh+fd (optimized)" "$zsh_wrapper"
    
    # Clean up temporary scripts
    rm -f "$bash_wrapper" "$zsh_wrapper"
    
    # Print report location
    print "\n\033[0;32mBenchmark complete!\033[0m"
    print "JSON report: $report_json"
    print "Markdown report: $report_md"
    
    # Print markdown report content
    print "\n\033[0;36m=== Benchmark Report ===\033[0m\n"
    cat "$report_md"
    
    # Generate summary
    generate_summary "$report_json" "$report_md" "$test_root" "$test_type" "$BENCHMARK_MODE"
}

# Generate a human-readable summary
generate_summary() {
    local json_file="$1"
    local md_file="$2"
    local test_root="$3"
    local test_type="$4"
    local mode="$5"
    
    local summary_file="$OUTPUT_DIR/summary_${TIMESTAMP}.md"
    
    cat > "$summary_file" << EOF
# Asimov Benchmark Summary

**Date:** $(date '+%Y-%m-%d %H:%M:%S')
**System:** $(uname -mrs)
**Test Environment:** $test_root ($test_type)
**Mode:** $mode

## Implementations Compared

1. **bash+find (original)**: Uses GNU find for directory search
2. **zsh+fd (optimized)**: Uses fd for parallel directory search with ZSH builtins

## Benchmark Configuration

- Warmup runs: $WARMUP
- Benchmark runs: $RUNS
- Test included: node_modules, .venv, target, vendor, .gradle directories

## Results

$(cat "$md_file")

## Key Findings

The optimized zsh+fd implementation is expected to be significantly faster because:

1. **fd is faster than find**: fd uses parallel directory traversal and is written in Rust
2. **ZSH builtins reduce subprocess overhead**: Native string manipulation vs external cut/grep
3. **Regex matching in fd**: Single pattern match vs multiple -name conditions

## Recommendations

See \`how-to-improve-the-performance-of-asimov.md\` for detailed optimization recommendations.
EOF
    
    print "\nSummary saved to: $summary_file"
}

# Run optimization benchmarks
run_optimization_benchmark() {
    local test_root="$1"
    local test_type="$2"
    
    print "\n\033[0;36mBenchmarking optimization combinations...\033[0m\n"
    
    local report_json="$OUTPUT_DIR/optimization_benchmark_${TIMESTAMP}.json"
    local report_md="$OUTPUT_DIR/optimization_benchmark_${TIMESTAMP}.md"
    
    # Create wrapper scripts for each optimization
    local base_wrapper=$(mktemp)
    local opt1_wrapper=$(mktemp)  # Cache
    local opt2_wrapper=$(mktemp)  # Incremental
    local opt3_wrapper=$(mktemp)  # Parallel
    local opt4_wrapper=$(mktemp)  # Gitignore
    local opt5_wrapper=$(mktemp)  # Memory-mapped cache
    local opt6_wrapper=$(mktemp)  # Skip size
    local all_wrapper=$(mktemp)   # All optimizations
    
    # Base: no optimizations
    cat > "$base_wrapper" << EOF
#!/usr/bin/env zsh
ASIMOV_ROOT='$test_root' ASIMOV_DRY_RUN=true ASIMOV_VERBOSE=false ${SCRIPT_DIR}/asimov-zsh 2>/dev/null | wc -l
EOF
    
    # OPT 1: Cache enabled (file-based grep)
    cat > "$opt1_wrapper" << EOF
#!/usr/bin/env zsh
rm -f ~/.cache/asimov-exclusions 2>/dev/null
ASIMOV_ROOT='$test_root' ASIMOV_DRY_RUN=true ASIMOV_VERBOSE=false ASIMOV_OPT_CACHE=true ${SCRIPT_DIR}/asimov-zsh 2>/dev/null | wc -l
EOF
    
    # OPT 2: Incremental (7 days)
    cat > "$opt2_wrapper" << EOF
#!/usr/bin/env zsh
ASIMOV_ROOT='$test_root' ASIMOV_DRY_RUN=true ASIMOV_VERBOSE=false ASIMOV_OPT_INCREMENTAL=true ${SCRIPT_DIR}/asimov-zsh 2>/dev/null | wc -l
EOF
    
    # OPT 3: Parallel tmutil
    cat > "$opt3_wrapper" << EOF
#!/usr/bin/env zsh
ASIMOV_ROOT='$test_root' ASIMOV_DRY_RUN=true ASIMOV_VERBOSE=false ASIMOV_OPT_PARALLEL=true ${SCRIPT_DIR}/asimov-zsh 2>/dev/null | wc -l
EOF
    
    # OPT 4: Gitignore awareness
    cat > "$opt4_wrapper" << EOF
#!/usr/bin/env zsh
ASIMOV_ROOT='$test_root' ASIMOV_DRY_RUN=true ASIMOV_VERBOSE=false ASIMOV_OPT_GITIGNORE=true ${SCRIPT_DIR}/asimov-zsh 2>/dev/null | wc -l
EOF
    
    # OPT 5: Memory-mapped cache (in-memory hash)
    cat > "$opt5_wrapper" << EOF
#!/usr/bin/env zsh
rm -f ~/.cache/asimov-exclusions 2>/dev/null
ASIMOV_ROOT='$test_root' ASIMOV_DRY_RUN=true ASIMOV_VERBOSE=false ASIMOV_OPT_CACHE=true ASIMOV_OPT_MMAP=true ${SCRIPT_DIR}/asimov-zsh 2>/dev/null | wc -l
EOF
    
    # OPT 6: Skip size calculation
    cat > "$opt6_wrapper" << EOF
#!/usr/bin/env zsh
ASIMOV_ROOT='$test_root' ASIMOV_DRY_RUN=true ASIMOV_VERBOSE=false ASIMOV_OPT_SKIP_SIZE=true ${SCRIPT_DIR}/asimov-zsh 2>/dev/null | wc -l
EOF
    
    # All optimizations combined
    cat > "$all_wrapper" << EOF
#!/usr/bin/env zsh
rm -f ~/.cache/asimov-exclusions 2>/dev/null
ASIMOV_ROOT='$test_root' ASIMOV_DRY_RUN=true ASIMOV_VERBOSE=false \
    ASIMOV_OPT_CACHE=true \
    ASIMOV_OPT_MMAP=true \
    ASIMOV_OPT_INCREMENTAL=true \
    ASIMOV_OPT_PARALLEL=true \
    ASIMOV_OPT_GITIGNORE=true \
    ASIMOV_OPT_SKIP_SIZE=true \
    ${SCRIPT_DIR}/asimov-zsh 2>/dev/null | wc -l
EOF
    
    chmod +x "$base_wrapper" "$opt1_wrapper" "$opt2_wrapper" "$opt3_wrapper" "$opt4_wrapper" "$opt5_wrapper" "$opt6_wrapper" "$all_wrapper"
    
    # Run hyperfine benchmark
    hyperfine \
        --warmup "$WARMUP" \
        --runs "$RUNS" \
        --export-json "$report_json" \
        --export-markdown "$report_md" \
        --command-name "Base (no opts)" "$base_wrapper" \
        --command-name "OPT1: Cache (grep)" "$opt1_wrapper" \
        --command-name "OPT2: Incremental" "$opt2_wrapper" \
        --command-name "OPT3: Parallel" "$opt3_wrapper" \
        --command-name "OPT4: Gitignore" "$opt4_wrapper" \
        --command-name "OPT5: Mmap Cache" "$opt5_wrapper" \
        --command-name "OPT6: Skip Size" "$opt6_wrapper" \
        --command-name "All Optimizations" "$all_wrapper"
    
    # Clean up
    rm -f "$base_wrapper" "$opt1_wrapper" "$opt2_wrapper" "$opt3_wrapper" "$opt4_wrapper" "$opt5_wrapper" "$opt6_wrapper" "$all_wrapper"
    
    # Print results
    print "\n\033[0;32mOptimization benchmark complete!\033[0m"
    print "JSON report: $report_json"
    print "Markdown report: $report_md"
    print "\n\033[0;36m=== Optimization Benchmark Results ===\033[0m\n"
    cat "$report_md"
}

# Main execution
main() {
    check_dependencies
    
    if $DRY_RUN; then
        print "Dry run mode - would benchmark the following scripts:"
        print "  Original: ${SCRIPT_DIR}/asimov"
        print "  Optimized: ${SCRIPT_DIR}/asimov-zsh"
        print "  Mode: $BENCHMARK_MODE"
        exit 0
    fi
    
    # Determine test root
    local test_root
    local test_type
    if $USE_TEMP_DIR; then
        test_root=$(mktemp -d)
        trap "cleanup_test_environment '$test_root'" EXIT
        create_test_environment "$test_root"
        test_type="synthetic (temp directory)"
    else
        test_root="$TEST_ROOT"
        if [[ ! -d "$test_root" ]]; then
            print "Error: Specified root directory does not exist: $test_root"
            exit 1
        fi
        test_type="real filesystem"
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    case "$BENCHMARK_MODE" in
        basic)
            run_benchmark
            ;;
        optimizations)
            run_optimization_benchmark "$test_root" "$test_type"
            ;;
        all)
            run_benchmark
            print "\n\033[0;33m--- Running optimization benchmarks ---\033[0m\n"
            run_optimization_benchmark "$test_root" "$test_type"
            ;;
        *)
            print "Unknown benchmark mode: $BENCHMARK_MODE"
            print "Valid modes: basic, optimizations, all"
            exit 1
            ;;
    esac
}

main "$@"
