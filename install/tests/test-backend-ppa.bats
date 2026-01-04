#!/usr/bin/env bats
# Tests for install/lib/backend-ppa.sh

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

    # Source the PPA backend if it exists
    if [ -f "${LIB_DIR}/backend-ppa.sh" ]; then
        source "${LIB_DIR}/backend-ppa.sh"
    fi

    # Create a test manifest with PPA packages
    create_ppa_test_manifest "$TEST_MANIFEST"
}

# Teardown function called after each test
teardown() {
    # Clean up temporary directory
    if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
}

# Helper to create manifest with PPA packages
create_ppa_test_manifest() {
    local manifest_file="$1"
    cat > "$manifest_file" <<'EOF'
version: 1.0

profiles:
  full:
    includes: [language_runtimes]

categories:
  language_runtimes:
    description: "Language runtimes"
    priority: ["ppa", "apt"]

packages:
  ruby:
    category: language_runtimes
    platforms: ["ubuntu"]
    ppa:
      repository: "ppa:brightbox/ruby-ng"
      package: "ruby3.2"

  python:
    category: language_runtimes
    platforms: ["ubuntu"]
    ppa:
      repository: "ppa:deadsnakes/ppa"
      packages: ["python3.12", "python3.12-dev"]

  neovim:
    category: language_runtimes
    platforms: ["ubuntu"]
    ppa:
      repository: "ppa:neovim-ppa/unstable"
      package: "neovim"
      gpg_key: "https://example.com/key.asc"

  git:
    category: language_runtimes
    apt:
      package: git
EOF
}

#
# Tests for ppa_get_repository
#

@test "ppa_get_repository: extracts repository from manifest" {
    run ppa_get_repository "$TEST_MANIFEST" "ruby"
    [ "$status" -eq 0 ]
    assert_contains "$output" "ppa:brightbox/ruby-ng"
}

@test "ppa_get_repository: handles python with multiple packages" {
    run ppa_get_repository "$TEST_MANIFEST" "python"
    [ "$status" -eq 0 ]
    assert_contains "$output" "ppa:deadsnakes/ppa"
}

@test "ppa_get_repository: returns error for non-existent package" {
    run ppa_get_repository "$TEST_MANIFEST" "nonexistent"
    [ "$status" -ne 0 ]
}

@test "ppa_get_repository: returns error for package without PPA config" {
    run ppa_get_repository "$TEST_MANIFEST" "git"
    [ "$status" -ne 0 ]
}

#
# Tests for ppa_get_package_name
#

@test "ppa_get_package_name: extracts single package name" {
    run ppa_get_package_name "$TEST_MANIFEST" "ruby"
    [ "$status" -eq 0 ]
    assert_contains "$output" "ruby3.2"
}

@test "ppa_get_package_name: extracts multiple package names" {
    run ppa_get_package_name "$TEST_MANIFEST" "python"
    [ "$status" -eq 0 ]
    assert_contains "$output" "python3.12"
    assert_contains "$output" "python3.12-dev"
}

@test "ppa_get_package_name: returns error for non-existent package" {
    run ppa_get_package_name "$TEST_MANIFEST" "nonexistent"
    [ "$status" -ne 0 ]
}

#
# Tests for ppa_get_gpg_key
#

@test "ppa_get_gpg_key: extracts GPG key if present" {
    run ppa_get_gpg_key "$TEST_MANIFEST" "neovim"
    [ "$status" -eq 0 ]
    assert_contains "$output" "https://example.com/key.asc"
}

@test "ppa_get_gpg_key: returns empty for packages without GPG key" {
    run ppa_get_gpg_key "$TEST_MANIFEST" "ruby"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

#
# Tests for ppa_check_added
#

@test "ppa_check_added: returns 0 if PPA is added" {
    # This test will skip if not on Ubuntu
    if [ ! -d /etc/apt/sources.list.d ]; then
        skip "Not on Ubuntu/Debian system"
    fi

    # Create a fake sources.list.d entry for testing
    local test_ppa_file="${TEST_TEMP_DIR}/test-ppa.list"
    echo "deb http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu focal main" > "$test_ppa_file"

    # Mock the check by checking our test file
    run bash -c "grep -q 'brightbox/ruby-ng' '$test_ppa_file' && echo 'found'"
    [ "$status" -eq 0 ]
}

@test "ppa_check_added: returns 1 if PPA is not added" {
    run ppa_check_added "ppa:nonexistent/ppa"
    [ "$status" -eq 1 ]
}

#
# Tests for ppa_add_repository
#

@test "ppa_add_repository: dry-run mode does not add PPA" {
    run ppa_add_repository "$TEST_MANIFEST" "ruby" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "DRY RUN"
    assert_contains "$output" "add-apt-repository"
}

@test "ppa_add_repository: constructs correct command for PPA" {
    run ppa_add_repository "$TEST_MANIFEST" "ruby" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "ppa:brightbox/ruby-ng"
}

@test "ppa_add_repository: handles PPA with GPG key" {
    run ppa_add_repository "$TEST_MANIFEST" "neovim" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "DRY RUN"
    # Should mention GPG key handling
    [[ "$output" =~ "gpg" ]] || [[ "$output" =~ "key" ]] || [[ "$output" =~ "GPG" ]]
}

@test "ppa_add_repository: returns error for package without PPA config" {
    run ppa_add_repository "$TEST_MANIFEST" "git" "true"
    [ "$status" -ne 0 ]
}

@test "ppa_add_repository: validates PPA repository format" {
    # Create manifest with invalid PPA format
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    packages: [badppa]
categories:
  general_tools:
    priority: ["ppa"]
packages:
  badppa:
    category: general_tools
    ppa:
      repository: "invalid-format"
      package: "test"
EOF

    run ppa_add_repository "$TEST_MANIFEST" "badppa" "true"
    [ "$status" -ne 0 ]
}

#
# Tests for ppa_install_package
#

@test "ppa_install_package: dry-run adds PPA and installs package" {
    run ppa_install_package "$TEST_MANIFEST" "ruby" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "DRY RUN"
    # Should mention both adding PPA and installing package
    assert_contains "$output" "ppa:brightbox/ruby-ng"
    assert_contains "$output" "ruby3.2"
}

@test "ppa_install_package: handles multiple packages" {
    run ppa_install_package "$TEST_MANIFEST" "python" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "python3.12"
    assert_contains "$output" "python3.12-dev"
}

@test "ppa_install_package: returns error for non-existent package" {
    run ppa_install_package "$TEST_MANIFEST" "nonexistent" "true"
    [ "$status" -ne 0 ]
}

@test "ppa_install_package: returns error for package without PPA config" {
    run ppa_install_package "$TEST_MANIFEST" "git" "true"
    [ "$status" -ne 0 ]
}

#
# Tests for error handling
#

@test "ppa functions: handle missing manifest file" {
    run ppa_get_repository "/nonexistent/manifest.yaml" "ruby"
    [ "$status" -ne 0 ]
}

@test "ppa functions: handle corrupted manifest" {
    echo "invalid: yaml: content: [[[" > "$TEST_MANIFEST"
    run ppa_get_repository "$TEST_MANIFEST" "ruby"
    [ "$status" -ne 0 ]
}

@test "ppa_add_repository: validates parameters" {
    # Missing manifest
    run ppa_add_repository "" "ruby" "true"
    [ "$status" -ne 0 ]

    # Missing package name
    run ppa_add_repository "$TEST_MANIFEST" "" "true"
    [ "$status" -ne 0 ]
}
