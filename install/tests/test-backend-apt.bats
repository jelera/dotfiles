#!/usr/bin/env bats
# Tests for install/lib/backend-apt.sh

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

    # Source the APT backend if it exists
    if [ -f "${LIB_DIR}/backend-apt.sh" ]; then
        source "${LIB_DIR}/backend-apt.sh"
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
# Tests for apt_get_package_name
#

@test "apt_get_package_name: extracts simple package name from manifest" {
    run apt_get_package_name "$TEST_MANIFEST" "git"
    [ "$status" -eq 0 ]
    assert_contains "$output" "git"
}

@test "apt_get_package_name: extracts package name from curl" {
    run apt_get_package_name "$TEST_MANIFEST" "curl"
    [ "$status" -eq 0 ]
    assert_contains "$output" "curl"
}

@test "apt_get_package_name: returns error for non-existent package" {
    run apt_get_package_name "$TEST_MANIFEST" "nonexistent"
    [ "$status" -ne 0 ]
}

@test "apt_get_package_name: returns error for package without apt config" {
    # ghostty only has homebrew config in test manifest
    run apt_get_package_name "$TEST_MANIFEST" "ghostty"
    [ "$status" -ne 0 ]
}

@test "apt_get_package_name: handles packages array if present" {
    # Create manifest with packages array in apt config
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    packages: [multi-package]
categories:
  general_tools:
    priority: ["apt"]
packages:
  multi-package:
    category: general_tools
    apt:
      packages: ["pkg1", "pkg2", "pkg3"]
EOF

    run apt_get_package_name "$TEST_MANIFEST" "multi-package"
    [ "$status" -eq 0 ]
    # Should return all packages in the array
    assert_contains "$output" "pkg1"
    assert_contains "$output" "pkg2"
    assert_contains "$output" "pkg3"
}

#
# Tests for apt_check_installed
#

@test "apt_check_installed: returns 0 for installed package" {
    # Skip if not on Linux (apt not available)
    if [[ "$(uname -s)" != "Linux" ]]; then
        skip "Test only runs on Linux"
    fi

    # bash is always installed in test environment
    run apt_check_installed "bash"
    [ "$status" -eq 0 ]
}

@test "apt_check_installed: returns 1 for non-installed package" {
    # Skip if not on Linux (apt not available)
    if [[ "$(uname -s)" != "Linux" ]]; then
        skip "Test only runs on Linux"
    fi

    # Use a package that's unlikely to be installed
    run apt_check_installed "nonexistent-package-xyz-123"
    [ "$status" -eq 1 ]
}

@test "apt_check_installed: handles dpkg-query errors gracefully" {
    # Skip if not on Linux (apt not available)
    if [[ "$(uname -s)" != "Linux" ]]; then
        skip "Test only runs on Linux"
    fi

    # Test with invalid package name that dpkg would reject
    run apt_check_installed ""
    [ "$status" -eq 1 ]
}

#
# Tests for apt_install_package
#

@test "apt_install_package: dry-run mode does not install" {
    # Use a package that's unlikely to be installed
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    packages: [cowsay]
categories:
  general_tools:
    priority: ["apt"]
packages:
  cowsay:
    category: general_tools
    apt:
      package: cowsay
EOF

    run apt_install_package "$TEST_MANIFEST" "cowsay" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "DRY RUN"
}

@test "apt_install_package: reports already installed packages" {
    # Skip if not on Linux (apt not available)
    if [[ "$(uname -s)" != "Linux" ]]; then
        skip "Test only runs on Linux"
    fi

    # bash is always installed
    # First, create a simple manifest with bash
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    packages: [bash]
categories:
  general_tools:
    priority: ["apt"]
packages:
  bash:
    category: general_tools
    apt:
      package: bash
EOF

    run apt_install_package "$TEST_MANIFEST" "bash" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "already installed"
}

@test "apt_install_package: returns error for package not in manifest" {
    run apt_install_package "$TEST_MANIFEST" "nonexistent" "true"
    [ "$status" -ne 0 ]
}

@test "apt_install_package: returns error for package without apt config" {
    run apt_install_package "$TEST_MANIFEST" "ghostty" "true"
    [ "$status" -ne 0 ]
}

@test "apt_install_package: constructs correct apt install command" {
    # Use a package that's unlikely to be installed
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    packages: [fortune-mod]
categories:
  general_tools:
    priority: ["apt"]
packages:
  fortune-mod:
    category: general_tools
    apt:
      package: fortune-mod
EOF

    run apt_install_package "$TEST_MANIFEST" "fortune-mod" "true"
    [ "$status" -eq 0 ]
    # Should mention the install command in dry-run output
    assert_contains "$output" "apt"
}

@test "apt_install_package: handles multi-package installation" {
    # Create manifest with packages array
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    packages: [multi-package]
categories:
  general_tools:
    priority: ["apt"]
packages:
  multi-package:
    category: general_tools
    apt:
      packages: ["curl", "wget", "tree"]
EOF

    run apt_install_package "$TEST_MANIFEST" "multi-package" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "curl"
    assert_contains "$output" "wget"
    assert_contains "$output" "tree"
}

#
# Tests for apt_install_bulk
#

@test "apt_install_bulk: dry-run mode processes multiple packages" {
    run apt_install_bulk "$TEST_MANIFEST" "git curl" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "git"
    assert_contains "$output" "curl"
}

@test "apt_install_bulk: handles empty package list" {
    run apt_install_bulk "$TEST_MANIFEST" "" "true"
    [ "$status" -eq 0 ]
}

@test "apt_install_bulk: handles whitespace-separated package list" {
    run apt_install_bulk "$TEST_MANIFEST" "git  curl   wget" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "git"
    assert_contains "$output" "curl"
    assert_contains "$output" "wget"
}

@test "apt_install_bulk: skips packages without apt config" {
    run apt_install_bulk "$TEST_MANIFEST" "git ghostty curl" "true"
    [ "$status" -eq 0 ]
    # Should process git and curl, skip ghostty
    assert_contains "$output" "git"
    assert_contains "$output" "curl"
}

@test "apt_install_bulk: reports summary of operations" {
    run apt_install_bulk "$TEST_MANIFEST" "git curl wget" "true"
    [ "$status" -eq 0 ]
    # Should provide a summary
    [[ "$output" =~ "3" ]] || [[ "$output" =~ "summary" ]] || [[ "$output" =~ "total" ]]
}

#
# Tests for error handling
#

@test "apt functions: handle missing manifest file" {
    run apt_get_package_name "/nonexistent/manifest.yaml" "git"
    [ "$status" -ne 0 ]
}

@test "apt functions: handle corrupted manifest" {
    echo "invalid: yaml: content: [[[" > "$TEST_MANIFEST"
    run apt_get_package_name "$TEST_MANIFEST" "git"
    [ "$status" -ne 0 ]
}

@test "apt_install_package: validates parameters" {
    # Missing manifest
    run apt_install_package "" "git" "true"
    [ "$status" -ne 0 ]

    # Missing package name
    run apt_install_package "$TEST_MANIFEST" "" "true"
    [ "$status" -ne 0 ]
}
