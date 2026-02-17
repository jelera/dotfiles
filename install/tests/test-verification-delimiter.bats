#!/usr/bin/env bats
# Test for delimiter fragility bug in verification.sh
# Tests that package identifiers with colons are handled correctly

load test-helper

setup() {
    export TEST_TEMP_DIR="$(mktemp -d)"

    # Define Unit Separator for tests (matches verification.sh)
    export US=$'\x1F'

    # Source verification functions
    if [ -f "${LIB_DIR}/verification.sh" ]; then
        source "${LIB_DIR}/verification.sh"
    fi
}

teardown() {
    if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
}

@test "parse_verification_issue: handles architecture-specific APT packages" {
    # Architecture-specific packages like "libc6:amd64" are common on Debian/Ubuntu
    local issue="apt${US}libc6${US}libc6:amd64${US}FUZZY${US}alt1|alt2"

    parse_verification_issue "$issue"

    [ "$ISSUE_BACKEND" = "apt" ]
    [ "$ISSUE_PKG" = "libc6" ]
    [ "$ISSUE_ACTUAL" = "libc6:amd64" ]  # Colon must be preserved
    [ "$ISSUE_STATUS" = "FUZZY" ]
    [ "$ISSUE_ALTS" = "alt1|alt2" ]
}

@test "parse_verification_issue: handles PPA repositories with ppa: prefix" {
    # PPA repositories start with "ppa:" by design
    local issue="ppa${US}python3${US}ppa:deadsnakes/ppa${US}MISSING${US}"

    parse_verification_issue "$issue"

    [ "$ISSUE_BACKEND" = "ppa" ]
    [ "$ISSUE_PKG" = "python3" ]
    [ "$ISSUE_ACTUAL" = "ppa:deadsnakes/ppa" ]  # "ppa:" prefix must be preserved
    [ "$ISSUE_STATUS" = "MISSING" ]
    [ -z "$ISSUE_ALTS" ]
}

@test "parse_verification_issue: handles alternatives with colons" {
    # Alternative packages might also have colons (though less common)
    local issue="apt${US}gcc${US}gcc-12${US}FUZZY${US}gcc:i386|gcc-11:amd64"

    parse_verification_issue "$issue"

    [ "$ISSUE_BACKEND" = "apt" ]
    [ "$ISSUE_PKG" = "gcc" ]
    [ "$ISSUE_ACTUAL" = "gcc-12" ]
    [ "$ISSUE_STATUS" = "FUZZY" ]
    [ "$ISSUE_ALTS" = "gcc:i386|gcc-11:amd64" ]  # Colons in alternatives preserved
}

@test "parse_verification_issue: handles empty alternatives field" {
    local issue="mise${US}ruby${US}ruby${US}MISSING${US}"

    parse_verification_issue "$issue"

    [ "$ISSUE_BACKEND" = "mise" ]
    [ "$ISSUE_PKG" = "ruby" ]
    [ "$ISSUE_ACTUAL" = "ruby" ]
    [ "$ISSUE_STATUS" = "MISSING" ]
    [ -z "$ISSUE_ALTS" ]
}

@test "VERIFICATION_ISSUES array: can store and retrieve issues with colons" {
    # Simulate what verify_apt_package does
    # US is already defined by sourcing verification.sh
    VERIFICATION_ISSUES+=("apt${US}libc6${US}libc6:amd64${US}FUZZY${US}alt1|alt2")
    VERIFICATION_ISSUES+=("ppa${US}python${US}ppa:user/repo${US}MISSING${US}")

    [ "${#VERIFICATION_ISSUES[@]}" -eq 2 ]

    # Parse first issue
    parse_verification_issue "${VERIFICATION_ISSUES[0]}"
    [ "$ISSUE_ACTUAL" = "libc6:amd64" ]

    # Parse second issue
    parse_verification_issue "${VERIFICATION_ISSUES[1]}"
    [ "$ISSUE_ACTUAL" = "ppa:user/repo" ]
}
