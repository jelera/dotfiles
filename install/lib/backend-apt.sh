#!/usr/bin/env bash
# APT package manager backend
# Provides manifest-aware package installation for APT/dpkg systems

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

# Get package name(s) from manifest for APT
# Usage: apt_get_package_name <manifest_file> <package_name>
# Returns: Package name(s) to install (one per line if multiple)
# Exit code: 0 on success, 1 on error
apt_get_package_name() {
    local manifest_file="$1"
    local package_name="$2"

    # Validate parameters
    if [[ -z "$manifest_file" ]] || [[ -z "$package_name" ]]; then
        echo "Error: Missing required parameters" >&2
        echo "Usage: apt_get_package_name <manifest_file> <package_name>" >&2
        return 1
    fi

    # Check if manifest file exists
    if [[ ! -f "$manifest_file" ]]; then
        echo "Error: Manifest file not found: $manifest_file" >&2
        return 1
    fi

    # Get APT config for the package
    local apt_config
    local exit_code
    apt_config=$(get_package_manager_config "$manifest_file" "$package_name" "apt" 2>&1)
    exit_code=$?

    if [[ "$exit_code" -ne 0 ]]; then
        echo "Error: Package '$package_name' not found in manifest or has no APT config" >&2
        return 1
    fi

    # Check if config has 'packages' array (multiple packages) or 'package' (single)
    local packages
    packages=$(echo "$apt_config" | yq eval '.packages // ""' - 2>/dev/null)

    if [[ -n "$packages" ]] && [[ "$packages" != "null" ]]; then
        # Multiple packages - return each on a new line
        echo "$packages"
    else
        # Single package
        local single_package
        single_package=$(echo "$apt_config" | yq eval '.package // ""' - 2>/dev/null)

        if [[ -z "$single_package" ]] || [[ "$single_package" = "null" ]]; then
            echo "Error: No package or packages field in APT config for '$package_name'" >&2
            return 1
        fi

        echo "$single_package"
    fi
}

# Check if a package is installed via APT/dpkg
# Usage: apt_check_installed <package_name>
# Returns: 0 if installed, 1 if not installed
apt_check_installed() {
    local package_name="$1"

    # Validate parameter
    if [[ -z "$package_name" ]]; then
        return 1
    fi

    # Check if package is installed using dpkg-query
    dpkg-query -W -f='${Status}' "$package_name" 2>/dev/null | grep -q "install ok installed"
    return $?
}

# Install a package using APT
# Usage: apt_install_package <manifest_file> <package_name> [dry_run]
# Parameters:
#   - manifest_file: Path to the package manifest
#   - package_name: Name of the package to install (as defined in manifest)
#   - dry_run: Set to "true" to simulate installation (optional, default: false)
# Returns: 0 on success, non-zero on error
apt_install_package() {
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

    # Get package name(s) from manifest
    local apt_packages
    local exit_code
    apt_packages=$(apt_get_package_name "$manifest_file" "$package_name" 2>&1)
    exit_code=$?

    if [[ "$exit_code" -ne 0 ]]; then
        echo "$apt_packages" >&2
        return "$exit_code"
    fi

    # Convert to array (handle multiple packages) - bash 3.2 compatible
    local packages_array
    local old_ifs="$IFS"
    IFS=$'\n'
    set -f
    # shellcheck disable=SC2206
    packages_array=($apt_packages)
    set +f
    IFS="$old_ifs"

    # Filter out empty entries
    local filtered_array=()
    local pkg
    for pkg in "${packages_array[@]}"; do
        [[ -n "$pkg" ]] && filtered_array+=("$pkg")
    done
    packages_array=("${filtered_array[@]}")

    # Check if we have any packages to install
    if [[ ${#packages_array[@]} -eq 0 ]]; then
        echo "Error: No packages to install" >&2
        return 1
    fi

    # Install packages (apt is idempotent - skips already installed packages)
    if [[ "$dry_run" = "true" ]]; then
        echo "[DRY RUN] Would install APT packages: ${packages_array[*]}"
        echo "[DRY RUN] Command: sudo apt install -y ${packages_array[*]}"
        return 0
    else
        echo "Installing APT packages: ${packages_array[*]}"
        sudo apt install -y "${packages_array[@]}"
        return $?
    fi
}

# Install multiple packages in bulk
# Usage: apt_install_bulk <manifest_file> <package_list> [dry_run]
# Parameters:
#   - manifest_file: Path to the package manifest
#   - package_list: Space-separated list of package names
#   - dry_run: Set to "true" to simulate installation (optional, default: false)
# Returns: 0 on success, non-zero on error
apt_install_bulk() {
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

    # Process each package
    for package_name in "${packages_array[@]}"; do
        # Skip empty entries
        [[ -z "$package_name" ]] && continue

        ((total++))

        # Try to install the package
        if apt_install_package "$manifest_file" "$package_name" "$dry_run" 2>&1; then
            ((succeeded++))
        else
            # Check if it's because the package doesn't have APT config (not an error)
            if ! apt_get_package_name "$manifest_file" "$package_name" >/dev/null 2>&1; then
                echo "Skipping '$package_name' (no APT configuration)"
                ((skipped++))
            else
                echo "Failed to install package: $package_name" >&2
                ((failed++))
            fi
        fi
    done

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
