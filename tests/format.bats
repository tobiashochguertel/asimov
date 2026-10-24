#!/usr/bin/env bats
#
# Unit tests for the format_size_kb() function.

load test_helper

setup() {
    load_format_size_kb
}

# =============================================================================
# KB range (< 1024 KB)
# =============================================================================

@test "format_size_kb: 0 → 0K" {
    run format_size_kb 0
    [[ "$output" == "0K" ]]
}

@test "format_size_kb: 1 → 1K" {
    run format_size_kb 1
    [[ "$output" == "1K" ]]
}

@test "format_size_kb: 512 → 512K" {
    run format_size_kb 512
    [[ "$output" == "512K" ]]
}

@test "format_size_kb: 1023 → 1023K" {
    run format_size_kb 1023
    [[ "$output" == "1023K" ]]
}

# =============================================================================
# MB range (1024 KB – 1048575 KB)
# =============================================================================

@test "format_size_kb: 1024 → 1.0M (exact boundary)" {
    run format_size_kb 1024
    [[ "$output" == "1.0M" ]]
}

@test "format_size_kb: 1535 → 1.4M (truncation, not rounding)" {
    # 1535 / 1024 = 1.499... → truncated to 1.4, not rounded to 1.5
    run format_size_kb 1535
    [[ "$output" == "1.4M" ]]
}

@test "format_size_kb: 1536 → 1.5M" {
    run format_size_kb 1536
    [[ "$output" == "1.5M" ]]
}

@test "format_size_kb: 10240 → 10.0M" {
    run format_size_kb 10240
    [[ "$output" == "10.0M" ]]
}

@test "format_size_kb: 512000 → 500.0M" {
    run format_size_kb 512000
    [[ "$output" == "500.0M" ]]
}

@test "format_size_kb: 1048575 → 1023.9M (just below GB boundary)" {
    run format_size_kb 1048575
    [[ "$output" == "1023.9M" ]]
}

# =============================================================================
# GB range (≥ 1048576 KB)
# =============================================================================

@test "format_size_kb: 1048576 → 1.0G (exact boundary)" {
    run format_size_kb 1048576
    [[ "$output" == "1.0G" ]]
}

@test "format_size_kb: 2621440 → 2.5G" {
    run format_size_kb 2621440
    [[ "$output" == "2.5G" ]]
}

@test "format_size_kb: 10485760 → 10.0G" {
    run format_size_kb 10485760
    [[ "$output" == "10.0G" ]]
}
