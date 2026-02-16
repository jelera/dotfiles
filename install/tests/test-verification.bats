#!/usr/bin/env bats
# Tests for verification module

# Setup test environment
setup() {
    # Load required modules
    SCRIPT_DIR="../lib"

    # Load cache module first
    if [[ -f "$SCRIPT_DIR/cache.sh" ]]; then
        # shellcheck source=../lib/cache.sh
        source "$SCRIPT_DIR/cache.sh"
    fi

    # Load verification module
    if [[ -f "$SCRIPT_DIR/verification.sh" ]]; then
        # shellcheck source=../lib/verification.sh
        source "$SCRIPT_DIR/verification.sh"
    fi

    # Clear any previous issues
    VERIFICATION_ISSUES=()
}

teardown() {
    VERIFICATION_ISSUES=()
    cache_clear_all
}

@test "verification: module loads successfully" {
    # Check that key functions are available
    command -v verify_packages_batch >/dev/null
    command -v has_verification_issues >/dev/null
    command -v get_verification_issues_count >/dev/null
}

@test "verification: VERIFICATION_ISSUES array initializes" {
    # Array should be empty initially
    [[ ${#VERIFICATION_ISSUES[@]} -eq 0 ]]
}

@test "has_verification_issues: returns false when no issues" {
    VERIFICATION_ISSUES=()

    run has_verification_issues
    assert_failure  # Should return 1 (false) when no issues
}

@test "has_verification_issues: returns true when issues exist" {
    VERIFICATION_ISSUES=("apt:test:test:MISSING:")

    run has_verification_issues
    assert_success  # Should return 0 (true) when issues exist
}

@test "get_verification_issues_count: returns correct count" {
    VERIFICATION_ISSUES=()
    count=$(get_verification_issues_count)
    [[ "$count" -eq 0 ]]

    VERIFICATION_ISSUES=("issue1" "issue2" "issue3")
    count=$(get_verification_issues_count)
    [[ "$count" -eq 3 ]]
}

@test "parse_verification_issue: parses issue string correctly" {
    local issue="apt:python-dev:python-dev:MISSING:"

    parse_verification_issue "$issue"

    [[ "$ISSUE_BACKEND" == "apt" ]]
    [[ "$ISSUE_PKG" == "python-dev" ]]
    [[ "$ISSUE_ACTUAL" == "python-dev" ]]
    [[ "$ISSUE_STATUS" == "MISSING" ]]
    [[ "$ISSUE_ALTS" == "" ]]
}

@test "parse_verification_issue: parses issue with alternatives" {
    local issue="apt:python-dev:python-dev:FUZZY:python3-dev|python3.9-dev"

    parse_verification_issue "$issue"

    [[ "$ISSUE_BACKEND" == "apt" ]]
    [[ "$ISSUE_PKG" == "python-dev" ]]
    [[ "$ISSUE_STATUS" == "FUZZY" ]]
    [[ "$ISSUE_ALTS" == "python3-dev|python3.9-dev" ]]
}

@test "format_verification_issues: displays no issues message" {
    VERIFICATION_ISSUES=()

    output=$(format_verification_issues)

    [[ "$output" == *"All packages verified"* ]]
}

@test "format_verification_issues: displays issues correctly" {
    VERIFICATION_ISSUES=(
        "apt:test-pkg:test-pkg:MISSING:"
        "homebrew:another:another:FUZZY:alt1|alt2"
    )

    output=$(format_verification_issues)

    [[ "$output" == *"2 package(s)"* ]]
    [[ "$output" == *"test-pkg"* ]]
    [[ "$output" == *"another"* ]]
}

@test "log_missing_packages: creates log file" {
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        skip "jq not available"
    fi

    VERIFICATION_ISSUES=(
        "apt:test-pkg:test-pkg:MISSING:"
    )

    # Create temp log file
    local temp_log
    temp_log=$(mktemp)

    log_missing_packages "$temp_log"

    # Check file was created
    [[ -f "$temp_log" ]]

    # Check it's valid JSON
    jq . "$temp_log" >/dev/null

    # Clean up
    rm -f "$temp_log"
}

@test "log_missing_packages: falls back to plain text without jq" {
    # Temporarily hide jq
    local original_path="$PATH"
    PATH="/nonexistent:$PATH"

    VERIFICATION_ISSUES=(
        "apt:test-pkg:test-pkg:MISSING:"
    )

    local temp_log
    temp_log=$(mktemp)

    run log_missing_packages "$temp_log"

    # Should still create file (as plain text)
    [[ -f "$temp_log" ]]

    # Restore PATH
    PATH="$original_path"

    # Clean up
    rm -f "$temp_log"
}

@test "load_missing_packages: loads packages from log" {
    # Skip if jq not available
    if ! command -v jq >/dev/null 2>&1; then
        skip "jq not available"
    fi

    # Create a test log file
    local temp_log
    temp_log=$(mktemp)

    cat > "$temp_log" <<EOF
{
  "date": "2024-01-01T00:00:00Z",
  "user": "testuser",
  "host": "testhost",
  "packages": [
    {
      "backend": "apt",
      "package": "pkg1",
      "actual_name": "pkg1",
      "status": "MISSING",
      "alternatives": []
    },
    {
      "backend": "homebrew",
      "package": "pkg2",
      "actual_name": "pkg2",
      "status": "MISSING",
      "alternatives": []
    }
  ]
}
EOF

    # Load packages
    packages=$(load_missing_packages "$temp_log")

    # Should contain both packages
    [[ "$packages" == *"pkg1"* ]]
    [[ "$packages" == *"pkg2"* ]]

    # Clean up
    rm -f "$temp_log"
}

@test "load_missing_packages: returns error for non-existent file" {
    run load_missing_packages "/nonexistent/file.json"
    assert_failure
}

# Helper functions
assert_success() {
    [[ "$status" -eq 0 ]]
}

assert_failure() {
    [[ "$status" -ne 0 ]]
}
