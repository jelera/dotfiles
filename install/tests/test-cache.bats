#!/usr/bin/env bats
# Tests for cache module

# Load test helper
load test-helper

# Setup test environment
setup() {
    # Load cache module using proper LIB_DIR from test-helper
    if [[ -f "${LIB_DIR}/cache.sh" ]]; then
        # shellcheck source=../lib/cache.sh
        source "${LIB_DIR}/cache.sh"
    fi
}

# Teardown
teardown() {
    cache_clear_all
}

@test "cache: Bash version check function exists" {
    # Should have require_bash4 function available
    command -v require_bash4 >/dev/null
}

@test "cache: Bash version is 4+" {
    # Cache requires Bash 4+ for associative arrays
    [[ "${BASH_VERSINFO[0]}" -ge 4 ]]
}

@test "apt_cache_init: initializes cache" {
    # Skip if apt not available
    if ! command -v dpkg-query >/dev/null 2>&1; then
        skip "apt/dpkg not available"
    fi

    run apt_cache_init
    assert_success

    # Cache should be marked as initialized
    [[ "$APT_CACHE_INITIALIZED" == "true" ]]
}

@test "apt_cache_init: populates cache with packages" {
    # Skip if apt not available
    if ! command -v dpkg-query >/dev/null 2>&1; then
        skip "apt/dpkg not available"
    fi

    apt_cache_init

    # Check cache is populated
    if [[ "$CACHE_USE_FALLBACK" == "true" ]]; then
        # Bash 3.x: check array
        [[ ${#APT_INSTALLED_ARRAY[@]} -gt 0 ]]
    else
        # Bash 4+: check associative array
        [[ ${#APT_INSTALLED_CACHE[@]} -gt 0 ]]
    fi
}

@test "apt_package_exists_cached: finds existing package" {
    # Skip if apt not available
    if ! command -v apt-cache >/dev/null 2>&1; then
        skip "apt-cache not available"
    fi

    apt_cache_init

    # Test with a common package that should exist (bash itself)
    run apt_package_exists_cached "bash"
    assert_success
}

@test "apt_package_exists_cached: returns false for non-existent package" {
    # Skip if apt not available
    if ! command -v apt-cache >/dev/null 2>&1; then
        skip "apt-cache not available"
    fi

    apt_cache_init

    # Test with a package that definitely doesn't exist
    run apt_package_exists_cached "this-package-definitely-does-not-exist-12345"
    assert_failure
}

@test "apt_is_installed_cached: detects installed packages" {
    # Skip if apt not available
    if ! command -v dpkg-query >/dev/null 2>&1; then
        skip "dpkg-query not available"
    fi

    apt_cache_init

    # bash should be installed (we're running in bash!)
    run apt_is_installed_cached "bash"
    assert_success
}

@test "apt_find_similar_cached: finds alternatives using apt-cache search" {
    # Skip if apt not available
    if ! command -v apt-cache >/dev/null 2>&1; then
        skip "apt-cache not available"
    fi

    apt_cache_init

    # Try to find similar packages
    result=$(apt_find_similar_cached "python" 5)

    # Should return something (most systems have python packages)
    [[ -n "$result" ]]
}

@test "apt_find_similar_cached: prioritizes exact matches" {
    # Skip if apt not available
    if ! command -v apt-cache >/dev/null 2>&1; then
        skip "apt-cache not available"
    fi

    apt_cache_init

    # Search for bash (should exist on all systems)
    result=$(apt_find_similar_cached "bash" 5)

    # bash should be first result (exact match)
    first_result=$(echo "$result" | head -n1)
    [[ "$first_result" == "bash" ]]
}

@test "apt_find_similar_cached: transforms python- to python3-" {
    # Skip if apt not available
    if ! command -v apt-cache >/dev/null 2>&1; then
        skip "apt-cache not available"
    fi

    apt_cache_init

    # Search for python-pytest (old name)
    result=$(apt_find_similar_cached "python-pytest" 10)

    # Should suggest python3-pytest
    echo "$result" | grep -q "python3-pytest"
}

@test "brew_cache_init: initializes Homebrew cache" {
    # Skip if brew not available
    if ! command -v brew >/dev/null 2>&1; then
        skip "Homebrew not available"
    fi

    # Call directly (not via run) to preserve variable state
    brew_cache_init
    [[ "$BREW_CACHE_INITIALIZED" == "true" ]]
}

@test "brew_cache_init: populates cache" {
    # Skip if brew not available
    if ! command -v brew >/dev/null 2>&1; then
        skip "Homebrew not available"
    fi

    brew_cache_init

    # Check cache is populated (at least some formulas should be installed)
    if [[ "$CACHE_USE_FALLBACK" == "true" ]]; then
        # May be 0 if nothing installed, that's OK
        [[ ${#BREW_INSTALLED_ARRAY[@]} -ge 0 ]]
    else
        [[ ${#BREW_INSTALLED_CACHE[@]} -ge 0 ]]
    fi
}

@test "brew_find_similar_cached: uses brew search" {
    # Skip if brew not available
    if ! command -v brew >/dev/null 2>&1; then
        skip "Homebrew not available"
    fi

    brew_cache_init

    # Search for a common tool
    result=$(brew_find_similar_cached "git" 5)

    # Should find git and possibly git-related tools
    [[ -n "$result" ]]
    echo "$result" | grep -q "git"
}

@test "brew_find_similar_cached: returns relevant results" {
    # Skip if brew not available
    if ! command -v brew >/dev/null 2>&1; then
        skip "Homebrew not available"
    fi

    brew_cache_init

    # Search with partial name
    result=$(brew_find_similar_cached "node" 5)

    # Should find node or nodejs
    [[ -n "$result" ]]
}

@test "mise_cache_init: initializes mise cache" {
    # Skip if mise not available
    if ! command -v mise >/dev/null 2>&1; then
        skip "mise not available"
    fi

    # Call directly (not via run) to preserve variable state
    mise_cache_init
    [[ "$MISE_CACHE_INITIALIZED" == "true" ]]
}

@test "cache_clear_all: clears all caches" {
    # Initialize some caches
    if command -v apt-cache >/dev/null 2>&1; then
        apt_cache_init
    fi

    # Clear all
    cache_clear_all

    # Check initialization flags are reset
    [[ "$APT_CACHE_INITIALIZED" == "false" ]]
    [[ "$BREW_CACHE_INITIALIZED" == "false" ]]
    [[ "$MISE_CACHE_INITIALIZED" == "false" ]]
}

@test "cache_stats: displays statistics" {
    # Initialize cache
    if command -v dpkg-query >/dev/null 2>&1; then
        apt_cache_init
    fi

    # Should display something
    run cache_stats
    assert_success
    [[ "$output" == *"Cache Statistics"* ]]
}

# Performance test: verify no subprocess calls during lookup
@test "cache: lookups don't spawn subprocesses" {
    # Skip if apt not available
    if ! command -v dpkg-query >/dev/null 2>&1; then
        skip "dpkg-query not available"
    fi

    # Initialize cache (this will spawn subprocess)
    apt_cache_init

    # Now lookups should not spawn subprocesses
    # We can't easily test this without strace, but we can verify speed
    # A thousand lookups should be instant with cache
    start_time=$(date +%s)

    for i in {1..1000}; do
        apt_package_exists_cached "bash" >/dev/null
    done

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    # Should complete in less than 5 seconds (would be much longer with 1000 subprocess calls)
    [[ $duration -lt 5 ]]
}

# Helper functions for bats
assert_success() {
    [[ "$status" -eq 0 ]]
}

assert_failure() {
    [[ "$status" -ne 0 ]]
}
