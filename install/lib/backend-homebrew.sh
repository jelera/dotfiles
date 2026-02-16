#!/usr/bin/env bash
# Homebrew package manager backend
# Provides manifest-aware package installation for Homebrew (formulas and casks)

# Ensure script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed directly" >&2
    exit 1
fi

# Source manifest parser if not already loaded
if ! command -v parse_manifest >/dev/null 2>&1; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${SCRIPT_DIR}/manifest-parser.sh" ]]; then
        # shellcheck source=./manifest-parser.sh
        source "${SCRIPT_DIR}/manifest-parser.sh"
    else
        echo "Error: manifest-parser.sh not found" >&2
        return 1
    fi
fi

# Get package name from manifest for Homebrew
# Usage: brew_get_package_name <manifest_file> <package_name>
# Returns: Package name to install
# Exit code: 0 on success, 1 on error
brew_get_package_name() {
    local manifest_file="$1"
    local package_name="$2"

    # Validate parameters
    if [[ -z "$manifest_file" ]] || [[ -z "$package_name" ]]; then
        echo "Error: Missing required parameters" >&2
        echo "Usage: brew_get_package_name <manifest_file> <package_name>" >&2
        return 1
    fi

    # Check if manifest file exists
    if [[ ! -f "$manifest_file" ]]; then
        echo "Error: Manifest file not found: $manifest_file" >&2
        return 1
    fi

    # Get Homebrew config for the package
    local brew_config
    local exit_code
    brew_config=$(get_package_manager_config "$manifest_file" "$package_name" "homebrew" 2>&1)
    exit_code=$?

    if [[ "$exit_code" -ne 0 ]]; then
        echo "Error: Package '$package_name' not found in manifest or has no Homebrew config" >&2
        return 1
    fi

    # Extract package name
    local pkg_name
    pkg_name=$(echo "$brew_config" | yq eval '.package // ""' - 2>/dev/null)

    if [[ -z "$pkg_name" ]] || [[ "$pkg_name" = "null" ]]; then
        echo "Error: No package field in Homebrew config for '$package_name'" >&2
        return 1
    fi

    echo "$pkg_name"
}

# Check if a package should be installed as a cask
# Usage: brew_is_cask <manifest_file> <package_name>
# Returns: 0 if cask, 1 if formula or error
brew_is_cask() {
    local manifest_file="$1"
    local package_name="$2"

    # Get Homebrew config for the package
    local brew_config
    if ! brew_config=$(get_package_manager_config "$manifest_file" "$package_name" "homebrew" 2>/dev/null); then
        return 1
    fi

    # Check if cask field is set to true
    local is_cask
    is_cask=$(echo "$brew_config" | yq eval '.cask // false' - 2>/dev/null)

    if [[ "$is_cask" = "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Check if a package is installed via Homebrew
# Usage: brew_check_installed <package_name> <is_cask>
# Parameters:
#   - package_name: Name of the package
#   - is_cask: "true" if it's a cask, "false" otherwise
# Returns: 0 if installed, 1 if not installed
brew_check_installed() {
    local package_name="$1"
    local is_cask="${2:-false}"

    # Validate parameter
    if [[ -z "$package_name" ]]; then
        return 1
    fi

    # Check if brew command exists
    if ! command -v brew >/dev/null 2>&1; then
        return 1
    fi

    # Check if package is installed
    if [[ "$is_cask" = "true" ]]; then
        brew list --cask "$package_name" >/dev/null 2>&1
    else
        brew list "$package_name" >/dev/null 2>&1
    fi

    return $?
}

# Install a package using Homebrew
# Usage: brew_install_package <manifest_file> <package_name> [dry_run]
# Parameters:
#   - manifest_file: Path to the package manifest
#   - package_name: Name of the package to install (as defined in manifest)
#   - dry_run: Set to "true" to simulate installation (optional, default: false)
# Returns: 0 on success, non-zero on error
brew_install_package() {
    local manifest_file="$1"
    local package_name="$2"
    local dry_run="${3:-false}"

    # Validate parameters
    if [[ -z "$manifest_file" ]]; then
        echo "Error: Missing manifest file parameter" >&2
        return 1
    fi

    if [[ -z "$package_name" ]]; then
        echo "Error: Missing package name parameter" >&2
        return 1
    fi

    # Get package name from manifest
    local brew_package
    local exit_code
    brew_package=$(brew_get_package_name "$manifest_file" "$package_name" 2>&1)
    exit_code=$?

    if [[ "$exit_code" -ne 0 ]]; then
        echo "$brew_package" >&2
        return "$exit_code"
    fi

    # Check if it's a cask
    local is_cask="false"
    if brew_is_cask "$manifest_file" "$package_name"; then
        is_cask="true"
    fi

    # Check if already installed
    if brew_check_installed "$brew_package" "$is_cask"; then
        echo "Package '$brew_package' is already installed"
        return 0
    fi

    # Install package
    if [[ "$dry_run" = "true" ]]; then
        if [[ "$is_cask" = "true" ]]; then
            echo "[DRY RUN] Would install Homebrew cask: $brew_package"
            echo "[DRY RUN] Command: brew install --cask $brew_package"
        else
            echo "[DRY RUN] Would install Homebrew formula: $brew_package"
            echo "[DRY RUN] Command: brew install $brew_package"
        fi
        return 0
    else
        echo "Installing Homebrew package: $brew_package"
        if [[ "$is_cask" = "true" ]]; then
            brew install --cask "$brew_package"
        else
            brew install "$brew_package"
        fi
        return $?
    fi
}

# Add a Homebrew tap (repository)
# Usage: brew_add_tap <tap_name> [dry_run]
# Parameters:
#   - tap_name: Name of the tap (format: user/repo)
#   - dry_run: Set to "true" to simulate adding tap (optional, default: false)
# Returns: 0 on success, non-zero on error
brew_add_tap() {
    local tap_name="$1"
    local dry_run="${2:-false}"

    # Validate parameter
    if [[ -z "$tap_name" ]]; then
        echo "Error: Missing tap name parameter" >&2
        return 1
    fi

    # Validate tap name format (should contain a slash)
    if [[ ! "$tap_name" =~ / ]]; then
        echo "Error: Invalid tap name format. Expected 'user/repo', got '$tap_name'" >&2
        return 1
    fi

    # Add tap
    if [[ "$dry_run" = "true" ]]; then
        echo "[DRY RUN] Would add Homebrew tap: $tap_name"
        echo "[DRY RUN] Command: brew tap $tap_name"
        return 0
    else
        echo "Adding Homebrew tap: $tap_name"
        brew tap "$tap_name"
        return $?
    fi
}

# Install multiple packages in bulk
# Usage: brew_install_bulk <manifest_file> <package_list> [dry_run]
# Parameters:
#   - manifest_file: Path to the package manifest
#   - package_list: Space-separated list of package names
#   - dry_run: Set to "true" to simulate installation (optional, default: false)
# Returns: 0 on success, non-zero on error
brew_install_bulk() {
    local manifest_file="$1"
    local package_list="$2"
    local dry_run="${3:-false}"

    # Handle empty package list
    if [[ -z "$package_list" ]]; then
        echo "No packages to install"
        return 0
    fi

    # Convert space-separated list to array - bash 3.2 compatible
    local packages_array
    # shellcheck disable=SC2206
    packages_array=($package_list)

    # Track statistics
    local total=0
    local succeeded=0
    local skipped=0
    local failed=0

    # Collect packages to install (brew install is idempotent)
    local formulas_to_install=()
    local casks_to_install=()

    # Process each package and categorize
    for package_name in "${packages_array[@]}"; do
        # Skip empty entries
        [[ -z "$package_name" ]] && continue

        ((total++))

        # Get package name from manifest
        local brew_package
        if ! brew_package=$(brew_get_package_name "$manifest_file" "$package_name" 2>&1); then
            echo "Skipping '$package_name' (no Homebrew configuration)"
            ((skipped++))
            continue
        fi

        # Check if it's a cask
        if brew_is_cask "$manifest_file" "$package_name"; then
            casks_to_install+=("$brew_package")
        else
            formulas_to_install+=("$brew_package")
        fi
    done

    # Install formulas in batch
    if [[ ${#formulas_to_install[@]} -gt 0 ]]; then
        if [[ "$dry_run" = "true" ]]; then
            echo "[DRY RUN] Would install Homebrew formulas: ${formulas_to_install[*]}"
            succeeded=$((succeeded + ${#formulas_to_install[@]}))
        else
            echo "Installing Homebrew formulas: ${formulas_to_install[*]}"
            if brew install "${formulas_to_install[@]}"; then
                succeeded=$((succeeded + ${#formulas_to_install[@]}))
            else
                failed=$((failed + ${#formulas_to_install[@]}))
            fi
        fi
    fi

    # Install casks in batch
    if [[ ${#casks_to_install[@]} -gt 0 ]]; then
        if [[ "$dry_run" = "true" ]]; then
            echo "[DRY RUN] Would install Homebrew casks: ${casks_to_install[*]}"
            succeeded=$((succeeded + ${#casks_to_install[@]}))
        else
            echo "Installing Homebrew casks: ${casks_to_install[*]}"
            if brew install --cask "${casks_to_install[@]}"; then
                succeeded=$((succeeded + ${#casks_to_install[@]}))
            else
                failed=$((failed + ${#casks_to_install[@]}))
            fi
        fi
    fi

    # Print summary
    echo ""
    echo "Installation summary:"
    echo "  Total packages: $total"
    echo "  Succeeded: $succeeded"
    echo "  Skipped: $skipped"
    echo "  Failed: $failed"

    # Return success if no failures
    [[ "$failed" -eq 0 ]]
}
