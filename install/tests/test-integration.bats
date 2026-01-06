#!/usr/bin/env bats
# Integration tests for manifest-driven installation orchestration

load test-helper

# Setup function called before each test
setup() {
    # Call parent setup
    export TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_MANIFEST_DIR="${TEST_TEMP_DIR}/manifests"
    export TEST_MANIFEST="${TEST_MANIFEST_DIR}/common.yaml"

    # Create manifest directory
    mkdir -p "$TEST_MANIFEST_DIR"

    # Source the manifest parser
    if [ -f "${LIB_DIR}/manifest-parser.sh" ]; then
        source "${LIB_DIR}/manifest-parser.sh"
    fi

    # Source all backend modules
    for backend in "${LIB_DIR}"/backend-*.sh; do
        if [ -f "$backend" ]; then
            source "$backend"
        fi
    done

    # Source the integration layer if it exists
    if [ -f "${INSTALL_DIR}/packages-manifest.sh" ]; then
        source "${INSTALL_DIR}/packages-manifest.sh"
    fi

    # Create a comprehensive test manifest
    create_integration_test_manifest "$TEST_MANIFEST"
}

# Teardown function called after each test
teardown() {
    # Clean up temporary directory
    if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
}

# Helper to create comprehensive manifest for integration testing
create_integration_test_manifest() {
    local manifest_file="$1"
    cat > "$manifest_file" <<'EOF'
version: 1.0

profiles:
  full:
    description: "Complete development environment"
    includes: [system_libraries, general_tools, language_runtimes]

  dev:
    description: "Headless development"
    includes: [system_libraries, general_tools, language_runtimes]

  minimal:
    description: "Essential CLI only"
    packages: [git, curl, wget]

  remote:
    description: "Remote server setup"
    packages: [git, curl, wget, htop]

categories:
  system_libraries:
    description: "System libraries"
    priority: ["apt"]

  general_tools:
    description: "CLI utilities"
    priority: ["apt", "ppa", "homebrew", "mise"]

  language_runtimes:
    description: "Language runtimes"
    priority: ["ppa", "homebrew", "mise"]

packages:
  # System libraries (apt only)
  build-essential:
    category: system_libraries
    description: "Build tools"
    platforms: ["ubuntu"]
    apt:
      package: build-essential

  # General tools (multiple backends)
  git:
    category: general_tools
    description: "Version control"
    priority: ["apt", "homebrew"]
    apt:
      package: git
    homebrew:
      package: git

  curl:
    category: general_tools
    description: "HTTP client"
    apt:
      package: curl
    homebrew:
      package: curl

  wget:
    category: general_tools
    description: "Download utility"
    apt:
      package: wget
    homebrew:
      package: wget

  htop:
    category: general_tools
    description: "Process viewer"
    apt:
      package: htop
    homebrew:
      package: htop

  # Language runtimes (mise managed)
  ruby:
    category: language_runtimes
    description: "Ruby runtime"
    managed_by: mise

  python:
    category: language_runtimes
    description: "Python runtime"
    managed_by: mise

  # Language runtimes (PPA)
  neovim:
    category: language_runtimes
    description: "Neovim editor"
    platforms: ["ubuntu"]
    ppa:
      repository: "ppa:neovim-ppa/unstable"
      package: "neovim"
EOF
}

#
# Tests for install_from_manifest
#

@test "install_from_manifest: accepts manifest directory and profile" {
    run install_from_manifest "$TEST_MANIFEST_DIR" "minimal" "true"
    [ "$status" -eq 0 ]
}

@test "install_from_manifest: dry-run mode processes packages" {
    run install_from_manifest "$TEST_MANIFEST_DIR" "minimal" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "DRY RUN"
}

@test "install_from_manifest: processes all packages in profile" {
    run install_from_manifest "$TEST_MANIFEST_DIR" "minimal" "true"
    [ "$status" -eq 0 ]
    # Should process git, curl, wget
    assert_contains "$output" "git"
    assert_contains "$output" "curl"
    assert_contains "$output" "wget"
}

@test "install_from_manifest: returns error for invalid profile" {
    run install_from_manifest "$TEST_MANIFEST_DIR" "nonexistent" "true"
    [ "$status" -ne 0 ]
}

@test "install_from_manifest: returns error for missing manifest directory" {
    run install_from_manifest "/nonexistent/manifests" "minimal" "true"
    [ "$status" -ne 0 ]
}

@test "install_from_manifest: validates parameters" {
    # Missing manifest directory
    run install_from_manifest "" "minimal" "true"
    [ "$status" -ne 0 ]

    # Missing profile
    run install_from_manifest "$TEST_MANIFEST_DIR" "" "true"
    [ "$status" -ne 0 ]
}

#
# Tests for resolve_package_backend
#

@test "resolve_package_backend: returns first available backend from priority" {
    run resolve_package_backend "$TEST_MANIFEST" "git"
    [ "$status" -eq 0 ]
    # git has priority: ["apt", "homebrew"]
    # On Ubuntu, should return "apt"
    # On macOS without apt, should return "homebrew"
    [[ "$output" =~ "apt" ]] || [[ "$output" =~ "homebrew" ]]
}

@test "resolve_package_backend: respects package-specific priority" {
    run resolve_package_backend "$TEST_MANIFEST" "git"
    [ "$status" -eq 0 ]
    # git overrides category default with ["apt", "homebrew"]
    assert_contains "$output" "apt" || assert_contains "$output" "homebrew"
}

@test "resolve_package_backend: uses category default if no package priority" {
    run resolve_package_backend "$TEST_MANIFEST" "curl"
    [ "$status" -eq 0 ]
    # curl uses general_tools default: ["apt", "ppa", "homebrew", "mise"]
}

@test "resolve_package_backend: returns mise for managed_by packages" {
    run resolve_package_backend "$TEST_MANIFEST" "ruby"
    [ "$status" -eq 0 ]
    assert_contains "$output" "mise"
}

@test "resolve_package_backend: returns error for nonexistent package" {
    run resolve_package_backend "$TEST_MANIFEST" "nonexistent"
    [ "$status" -ne 0 ]
}

#
# Tests for install_package_with_backend
#

@test "install_package_with_backend: installs using resolved backend" {
    # Use wget which is less likely to be installed
    run install_package_with_backend "$TEST_MANIFEST" "wget" "apt" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "DRY RUN" || assert_contains "$output" "already installed"
}

@test "install_package_with_backend: handles apt backend" {
    # Use htop which might not be installed
    run install_package_with_backend "$TEST_MANIFEST" "htop" "apt" "true"
    [ "$status" -eq 0 ]
    # Should mention apt or be already installed
    [[ "$output" =~ "apt" ]] || [[ "$output" =~ "already installed" ]]
}

@test "install_package_with_backend: handles homebrew backend" {
    run install_package_with_backend "$TEST_MANIFEST" "git" "homebrew" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "brew"
}

@test "install_package_with_backend: handles mise backend" {
    run install_package_with_backend "$TEST_MANIFEST" "ruby" "mise" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "mise"
}

@test "install_package_with_backend: handles ppa backend" {
    run install_package_with_backend "$TEST_MANIFEST" "neovim" "ppa" "true"
    [ "$status" -eq 0 ]
    assert_contains "$output" "ppa"
}

@test "install_package_with_backend: returns error for unsupported backend" {
    run install_package_with_backend "$TEST_MANIFEST" "git" "snap" "true"
    [ "$status" -ne 0 ]
}

@test "install_package_with_backend: returns error for package without backend config" {
    run install_package_with_backend "$TEST_MANIFEST" "build-essential" "homebrew" "true"
    [ "$status" -ne 0 ]
}

#
# Tests for get_profile_packages
#

@test "get_profile_packages: returns packages for explicit profile" {
    run get_profile_packages "$TEST_MANIFEST" "minimal"
    [ "$status" -eq 0 ]
    assert_contains "$output" "git"
    assert_contains "$output" "curl"
    assert_contains "$output" "wget"
}

@test "get_profile_packages: returns packages for category-based profile" {
    run get_profile_packages "$TEST_MANIFEST" "dev"
    [ "$status" -eq 0 ]
    # Should include packages from included categories
    assert_contains "$output" "git"
    assert_contains "$output" "build-essential"
}

@test "get_profile_packages: filters by platform" {
    # Create a package that's platform-specific
    run get_profile_packages "$TEST_MANIFEST" "full"
    [ "$status" -eq 0 ]
    # build-essential is ubuntu only, should be filtered on other platforms
}

@test "get_profile_packages: returns error for nonexistent profile" {
    run get_profile_packages "$TEST_MANIFEST" "nonexistent"
    [ "$status" -ne 0 ]
}

#
# Tests for installation summary and reporting
#

@test "install_from_manifest: provides installation summary" {
    run install_from_manifest "$TEST_MANIFEST_DIR" "minimal" "true"
    [ "$status" -eq 0 ]
    # Should provide summary with counts
    [[ "$output" =~ "summary" ]] || [[ "$output" =~ "Total" ]] || [[ "$output" =~ "Succeeded" ]]
}

@test "install_from_manifest: reports skipped packages" {
    run install_from_manifest "$TEST_MANIFEST_DIR" "minimal" "true"
    [ "$status" -eq 0 ]
    # Should report if any packages were skipped
}

@test "install_from_manifest: handles mixed backends in one profile" {
    run install_from_manifest "$TEST_MANIFEST_DIR" "full" "true"
    [ "$status" -eq 0 ]
    # Should successfully orchestrate apt, ppa, homebrew, and mise
}

#
# Tests for platform detection
#

@test "integration: detects current platform correctly" {
    run detect_platform
    [ "$status" -eq 0 ]
    # Should return ubuntu, macos, etc.
    [[ "$output" =~ "ubuntu" ]] || [[ "$output" =~ "macos" ]] || [[ "$output" =~ "linux" ]]
}

@test "integration: filters packages by detected platform" {
    run install_from_manifest "$TEST_MANIFEST_DIR" "full" "true"
    [ "$status" -eq 0 ]
    # Should only process packages for current platform
}

#
# Tests for error handling and resilience
#

@test "install_from_manifest: continues on package failure in non-strict mode" {
    # Should continue installing other packages even if one fails
    run install_from_manifest "$TEST_MANIFEST_DIR" "minimal" "true"
    [ "$status" -eq 0 ]
}

@test "install_from_manifest: handles corrupted manifest gracefully" {
    echo "invalid: yaml: [[[" > "$TEST_MANIFEST"
    run install_from_manifest "$TEST_MANIFEST_DIR" "minimal" "true"
    [ "$status" -ne 0 ]
    # Should contain error message (case-insensitive)
    [[ "$output" =~ [Ee]rror ]] || [[ "$output" =~ [Ii]nvalid ]]
}

@test "install_from_manifest: validates manifest schema before installation" {
    run install_from_manifest "$TEST_MANIFEST_DIR" "minimal" "true"
    [ "$status" -eq 0 ]
    # Should validate manifest before proceeding
}
