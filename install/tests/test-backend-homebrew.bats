#!/usr/bin/env bats
# Tests for install/lib/backend-homebrew.sh

load test-helper

# Setup function called before each test
setup() {
    # Call parent setup
    export TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_MANIFEST="${TEST_TEMP_DIR}/test-packages.yaml"

    # Source the manifest parser if it exists
    if [ -f "${LIB_DIR}/manifest-parser.sh" ]; then
        source "${LIB_DIR}/manifest-parser.sh"
    fi

    # Source the Homebrew backend if it exists
    if [ -f "${LIB_DIR}/backend-homebrew.sh" ]; then
        source "${LIB_DIR}/backend-homebrew.sh"
    fi

    # Create a test manifest
    create_test_manifest "$TEST_MANIFEST"
}

# Teardown function called after each test
teardown() {
    # Clean up temporary directory
    if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
}

#
# Tests for brew_get_package_name
#

@test "brew_get_package_name: extracts simple package name from manifest" {
    run brew_get_package_name "$TEST_MANIFEST" "git"
    [ "$status" -eq 0 ]
    assert_contains "$output" "git"
}

@test "brew_get_package_name: extracts package name from curl" {
    run brew_get_package_name "$TEST_MANIFEST" "curl"
    [ "$status" -eq 0 ]
    assert_contains "$output" "curl"
}

@test "brew_get_package_name: returns error for non-existent package" {
    run brew_get_package_name "$TEST_MANIFEST" "nonexistent"
    [ "$status" -ne 0 ]
}

@test "brew_get_package_name: returns error for package without homebrew config" {
    # build-essential only has apt config
    run brew_get_package_name "$TEST_MANIFEST" "build-essential"
    [ "$status" -ne 0 ]
}

#
# Tests for brew_is_cask
#

@test "brew_is_cask: returns true for cask packages" {
    run brew_is_cask "$TEST_MANIFEST" "ghostty"
    [ "$status" -eq 0 ]
}

@test "brew_is_cask: returns false for formula packages" {
    run brew_is_cask "$TEST_MANIFEST" "git"
    [ "$status" -eq 1 ]
}

@test "brew_is_cask: returns false for packages without homebrew config" {
    run brew_is_cask "$TEST_MANIFEST" "build-essential"
    [ "$status" -eq 1 ]
}

#
# Tests for brew_check_installed
#

@test "brew_check_installed: detects installed formulas" {
    # Skip if brew is not available
    if ! command -v brew >/dev/null 2>&1; then
        skip "Homebrew not installed"
    fi

    # bash is typically installed via homebrew on macOS
    if brew list bash >/dev/null 2>&1; then
        run brew_check_installed "bash" "false"
        [ "$status" -eq 0 ]
    else
        skip "bash formula not installed"
    fi
}

@test "brew_check_installed: detects installed casks" {
    # Skip if brew is not available
    if ! command -v brew >/dev/null 2>&1; then
        skip "Homebrew not installed"
    fi

    # Check for any installed cask
    if brew list --cask 2>/dev/null | head -n 1 | grep -q .; then
        local cask_name
        cask_name=$(brew list --cask 2>/dev/null | head -n 1)
        run brew_check_installed "$cask_name" "true"
        [ "$status" -eq 0 ]
    else
        skip "No casks installed"
    fi
}

@test "brew_check_installed: returns 1 for non-installed package" {
    # Skip if brew is not available
    if ! command -v brew >/dev/null 2>&1; then
        skip "Homebrew not installed"
    fi

    run brew_check_installed "nonexistent-package-xyz-123" "false"
    [ "$status" -eq 1 ]
}

#
# Tests for brew_install_package
#

@test "brew_install_package: dry-run mode does not install formula" {
    # Use a package unlikely to be installed
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    packages: [ponysay]
categories:
  general_tools:
    priority: ["homebrew"]
packages:
  ponysay:
    category: general_tools
    homebrew:
      package: ponysay
EOF

    run brew_install_package "$TEST_MANIFEST" "ponysay" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "DRY RUN"
}

@test "brew_install_package: dry-run mode handles casks" {
    run brew_install_package "$TEST_MANIFEST" "ghostty" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "DRY RUN"
    assert_contains "$output" "cask"
}

@test "brew_install_package: returns error for package not in manifest" {
    run brew_install_package "$TEST_MANIFEST" "nonexistent" "true"
    [ "$status" -ne 0 ]
}

@test "brew_install_package: returns error for package without homebrew config" {
    run brew_install_package "$TEST_MANIFEST" "build-essential" "true"
    [ "$status" -ne 0 ]
}

@test "brew_install_package: constructs correct brew install command for formula" {
    # Use a package unlikely to be installed
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    packages: [sl]
categories:
  general_tools:
    priority: ["homebrew"]
packages:
  sl:
    category: general_tools
    homebrew:
      package: sl
EOF

    run brew_install_package "$TEST_MANIFEST" "sl" "true"
    [ "$status" -eq 0 ]
    # Should mention brew install
    assert_contains "$output" "brew install"
}

@test "brew_install_package: constructs correct brew install command for cask" {
    run brew_install_package "$TEST_MANIFEST" "ghostty" "true"
    [ "$status" -eq 0 ]
    # Should mention brew install --cask
    assert_contains "$output" "brew install --cask"
}

#
# Tests for brew_add_tap
#

@test "brew_add_tap: dry-run mode does not add tap" {
    run brew_add_tap "homebrew/cask-fonts" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "DRY RUN"
    assert_contains "$output" "brew tap"
}

@test "brew_add_tap: validates tap name format" {
    # Tap names should be in the format "user/repo"
    run brew_add_tap "invalid-tap-name" "true"
    [ "$status" -ne 0 ]
}

@test "brew_add_tap: handles empty tap name" {
    run brew_add_tap "" "true"
    [ "$status" -ne 0 ]
}

#
# Tests for brew_install_bulk
#

@test "brew_install_bulk: dry-run mode processes multiple packages" {
    run brew_install_bulk "$TEST_MANIFEST" "git curl wget" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "git"
    assert_contains "$output" "curl"
    assert_contains "$output" "wget"
}

@test "brew_install_bulk: handles empty package list" {
    run brew_install_bulk "$TEST_MANIFEST" "" "true"
    [ "$status" -eq 0 ]
}

@test "brew_install_bulk: handles mixed formulas and casks" {
    run brew_install_bulk "$TEST_MANIFEST" "git ghostty curl" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "git"
    assert_contains "$output" "ghostty"
    assert_contains "$output" "curl"
}

@test "brew_install_bulk: skips packages without homebrew config" {
    run brew_install_bulk "$TEST_MANIFEST" "git build-essential curl" "true"
    [ "$status" -eq 0 ]
    # Should process git and curl, skip build-essential
    assert_contains "$output" "git"
    assert_contains "$output" "curl"
}

@test "brew_install_bulk: reports summary of operations" {
    run brew_install_bulk "$TEST_MANIFEST" "git curl wget" "true"
    [ "$status" -eq 0 ]
    # Should provide a summary
    [[ "$output" =~ "3" ]] || [[ "$output" =~ "summary" ]] || [[ "$output" =~ "total" ]]
}

#
# Tests for error handling
#

@test "brew functions: handle missing manifest file" {
    run brew_get_package_name "/nonexistent/manifest.yaml" "git"
    [ "$status" -ne 0 ]
}

@test "brew functions: handle corrupted manifest" {
    echo "invalid: yaml: content: [[[" > "$TEST_MANIFEST"
    run brew_get_package_name "$TEST_MANIFEST" "git"
    [ "$status" -ne 0 ]
}

@test "brew_install_package: validates parameters" {
    # Missing manifest
    run brew_install_package "" "git" "true"
    [ "$status" -ne 0 ]

    # Missing package name
    run brew_install_package "$TEST_MANIFEST" "" "true"
    [ "$status" -ne 0 ]
}
