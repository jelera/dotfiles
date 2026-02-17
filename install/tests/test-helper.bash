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

# ==============================================================================
# Mock Functions for Expensive System Calls
# ==============================================================================
# Enable with: MOCK_SYSTEM_CALLS=1 make -f test.mk test
# These mocks reduce test time by avoiding real package manager queries

mock_dpkg_query() {
    # Mock dpkg-query -W (list installed packages)
    if [[ "$1" == "-W" ]] && [[ "$2" == "-f" ]]; then
        cat << 'EOF'
bash
curl
git
build-essential
tmux
wget
python3
neovim
EOF
        return 0
    fi
    return 1
}

mock_apt_cache() {
    # Mock apt-cache pkgnames
    if [[ "$1" == "pkgnames" ]]; then
        cat << 'EOF'
bash
curl
git
wget
build-essential
python3
python3-dev
python3-pip
tmux
neovim
zsh
EOF
        return 0
    fi

    # Mock apt-cache search
    if [[ "$1" == "search" ]]; then
        local pattern="$2"
        case "$pattern" in
            python*)
                echo "python3 - Python 3 interpreter"
                echo "python3-dev - Python 3 development files"
                echo "python3-pip - Python package installer"
                ;;
            build*)
                echo "build-essential - Essential build tools"
                ;;
            *)
                echo "Package search results for: $pattern"
                ;;
        esac
        return 0
    fi
    return 1
}

mock_brew_list() {
    # Mock brew list --formula
    if [[ "$1" == "--formula" ]]; then
        cat << 'EOF'
git
curl
wget
bash
neovim
zsh
EOF
        return 0
    fi

    # Mock brew list --cask
    if [[ "$1" == "--cask" ]]; then
        cat << 'EOF'
ghostty
iterm2
EOF
        return 0
    fi

    return 1
}

mock_mise_ls_remote() {
    # Mock mise ls-remote <tool>
    local tool="$1"
    case "$tool" in
        ruby)
            echo "3.2.0"
            echo "3.1.0"
            echo "3.0.0"
            ;;
        python)
            echo "3.11.0"
            echo "3.10.0"
            echo "3.9.0"
            ;;
        node)
            echo "20.0.0"
            echo "18.0.0"
            echo "16.0.0"
            ;;
        go)
            echo "1.21.0"
            echo "1.20.0"
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

# Apply mocks if MOCK_SYSTEM_CALLS=1
if [[ "${MOCK_SYSTEM_CALLS:-0}" == "1" ]]; then
    dpkg-query() { mock_dpkg_query "$@"; }
    apt-cache() { mock_apt_cache "$@"; }
    brew() {
        case "$1" in
            list) mock_brew_list "${@:2}" ;;
            *) command brew "$@" 2>/dev/null || return 1 ;;
        esac
    }
    mise() {
        case "$1" in
            ls-remote) mock_mise_ls_remote "$2" ;;
            *) command mise "$@" 2>/dev/null || return 1 ;;
        esac
    }
    export -f dpkg-query apt-cache brew mise 2>/dev/null || true
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
