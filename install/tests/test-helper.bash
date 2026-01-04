#!/usr/bin/env bash
# Common test utilities and fixtures for bats tests

# Setup bats and bats-support libraries
# Load bats-support if available (for better assertions)
if [ -f "/usr/lib/bats-support/load.bash" ]; then
    load "/usr/lib/bats-support/load.bash"
fi

# Set up test environment
export DOTFILES_DIR="${BATS_TEST_DIRNAME}/../.."
export INSTALL_DIR="${DOTFILES_DIR}/install"
export LIB_DIR="${INSTALL_DIR}/lib"
export MANIFEST_DIR="${INSTALL_DIR}/manifests"
export FIXTURES_DIR="${BATS_TEST_DIRNAME}/fixtures"

# Source common functions if they exist
if [ -f "${INSTALL_DIR}/common.sh" ]; then
    # Mock logging functions for tests to reduce noise
    export DRY_RUN=true
    export QUIET_MODE=true
fi

# Helper function: Create a minimal test manifest
create_test_manifest() {
    local manifest_file="$1"
    cat > "$manifest_file" <<'EOF'
version: 1.0

profiles:
  full:
    description: "Complete development environment"
    includes: [system_libraries, general_tools]

  minimal:
    description: "Essential CLI only"
    packages: [git, curl]

categories:
  system_libraries:
    description: "System-level libraries"
    priority: ["apt"]

  general_tools:
    description: "CLI utilities"
    priority: ["apt", "homebrew"]

packages:
  git:
    category: general_tools
    priority: ["apt", "homebrew"]
    apt:
      package: git
    homebrew:
      package: git

  curl:
    category: general_tools
    apt:
      package: curl
    homebrew:
      package: curl

  build-essential:
    category: system_libraries
    platforms: ["ubuntu"]
    apt:
      package: build-essential

  ghostty:
    category: general_tools
    platforms: ["macos"]
    homebrew:
      cask: true
      package: ghostty
EOF
}

# Helper function: Create invalid manifest (missing version)
create_invalid_manifest() {
    local manifest_file="$1"
    cat > "$manifest_file" <<'EOF'
packages:
  git:
    category: general_tools
EOF
}

# Helper function: Clean up test files
cleanup_test_files() {
    if [ -n "$BATS_TEST_TMPDIR" ]; then
        rm -rf "${BATS_TEST_TMPDIR:?}"/*
    fi
}

# Setup function called before each test
setup() {
    # Create temporary directory for this test
    export TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_MANIFEST="${TEST_TEMP_DIR}/test-packages.yaml"

    # Source the manifest parser if it exists
    if [ -f "${LIB_DIR}/manifest-parser.sh" ]; then
        source "${LIB_DIR}/manifest-parser.sh"
    fi
}

# Teardown function called after each test
teardown() {
    # Clean up temporary directory
    if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
}

# Helper assertions
assert_file_exists() {
    local file="$1"
    [ -f "$file" ] || {
        echo "Expected file to exist: $file"
        return 1
    }
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    [[ "$haystack" =~ $needle ]] || {
        echo "Expected to find '$needle' in output"
        echo "Got: $haystack"
        return 1
    }
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    [[ ! "$haystack" =~ $needle ]] || {
        echo "Did not expect to find '$needle' in output"
        echo "Got: $haystack"
        return 1
    }
}
