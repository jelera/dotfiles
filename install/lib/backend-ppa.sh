#!/usr/bin/env bash
# PPA (Personal Package Archive) backend for Ubuntu
# Provides manifest-aware PPA repository and package installation

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

# Get PPA repository from manifest
# Usage: ppa_get_repository <manifest_file> <package_name>
# Returns: PPA repository string (e.g., "ppa:user/repo")
# Exit code: 0 on success, 1 on error
ppa_get_repository() {
    local manifest_file="$1"
    local package_name="$2"

    # Validate parameters
    if [[ -z "$manifest_file" ]] || [[ -z "$package_name" ]]; then
        echo "Error: Missing required parameters" >&2
        echo "Usage: ppa_get_repository <manifest_file> <package_name>" >&2
        return 1
    fi

    # Check if manifest file exists
    if [[ ! -f "$manifest_file" ]]; then
        echo "Error: Manifest file not found: $manifest_file" >&2
        return 1
    fi

    # Get PPA config for the package
    local ppa_config
    local exit_code
    ppa_config=$(get_package_manager_config "$manifest_file" "$package_name" "ppa" 2>&1)
    exit_code=$?

    if [[ "$exit_code" -ne 0 ]]; then
        echo "Error: Package '$package_name' not found in manifest or has no PPA config" >&2
        return 1
    fi

    # Extract repository
    local repository
    repository=$(echo "$ppa_config" | yq eval '.repository // ""' - 2>/dev/null)

    if [[ -z "$repository" ]] || [[ "$repository" = "null" ]]; then
        echo "Error: No repository field in PPA config for '$package_name'" >&2
        return 1
    fi

    # Validate PPA format (must start with "ppa:")
    if [[ ! "$repository" =~ ^ppa: ]]; then
        echo "Error: Invalid PPA format. Must start with 'ppa:' but got '$repository'" >&2
        return 1
    fi

    echo "$repository"
}

# Get package name(s) from manifest for PPA
# Usage: ppa_get_package_name <manifest_file> <package_name>
# Returns: Package name(s) to install (one per line if multiple)
# Exit code: 0 on success, 1 on error
ppa_get_package_name() {
    local manifest_file="$1"
    local package_name="$2"

    # Validate parameters
    if [[ -z "$manifest_file" ]] || [[ -z "$package_name" ]]; then
        echo "Error: Missing required parameters" >&2
        echo "Usage: ppa_get_package_name <manifest_file> <package_name>" >&2
        return 1
    fi

    # Check if manifest file exists
    if [[ ! -f "$manifest_file" ]]; then
        echo "Error: Manifest file not found: $manifest_file" >&2
        return 1
    fi

    # Get PPA config for the package
    local ppa_config
    local exit_code
    ppa_config=$(get_package_manager_config "$manifest_file" "$package_name" "ppa" 2>&1)
    exit_code=$?

    if [[ "$exit_code" -ne 0 ]]; then
        echo "Error: Package '$package_name' not found in manifest or has no PPA config" >&2
        return 1
    fi

    # Check if config has 'packages' array (multiple packages) or 'package' (single)
    local packages
    packages=$(echo "$ppa_config" | yq eval '.packages // ""' - 2>/dev/null)

    if [[ -n "$packages" ]] && [[ "$packages" != "null" ]]; then
        # Multiple packages - return each on a new line
        echo "$packages"
    else
        # Single package
        local single_package
        single_package=$(echo "$ppa_config" | yq eval '.package // ""' - 2>/dev/null)

        if [[ -z "$single_package" ]] || [[ "$single_package" = "null" ]]; then
            echo "Error: No package or packages field in PPA config for '$package_name'" >&2
            return 1
        fi

        echo "$single_package"
    fi
}

# Get GPG key URL from manifest for PPA
# Usage: ppa_get_gpg_key <manifest_file> <package_name>
# Returns: GPG key URL if present, empty string otherwise
# Exit code: 0 on success
ppa_get_gpg_key() {
    local manifest_file="$1"
    local package_name="$2"

    # Get PPA config for the package
    local ppa_config
    if ! ppa_config=$(get_package_manager_config "$manifest_file" "$package_name" "ppa" 2>/dev/null); then
        return 0  # Not an error, just no GPG key
    fi

    # Extract GPG key (optional field)
    local gpg_key
    gpg_key=$(echo "$ppa_config" | yq eval '.gpg_key // ""' - 2>/dev/null)

    if [[ -n "$gpg_key" ]] && [[ "$gpg_key" != "null" ]]; then
        echo "$gpg_key"
    fi

    return 0
}

# Check if a PPA repository is already added
# Usage: ppa_check_added <repository>
# Returns: 0 if added, 1 if not added
ppa_check_added() {
    local repository="$1"

    # Extract the PPA name (remove "ppa:" prefix)
    local ppa_name="${repository#ppa:}"

    # Check if the PPA is in sources.list or sources.list.d
    if [[ -d /etc/apt/sources.list.d ]]; then
        grep -rq "$ppa_name" /etc/apt/sources.list.d/ 2>/dev/null && return 0
    fi

    return 1
}

# Add a PPA repository
# Usage: ppa_add_repository <manifest_file> <package_name> [dry_run]
# Parameters:
#   - manifest_file: Path to the package manifest
#   - package_name: Name of the package (to get PPA info from manifest)
#   - dry_run: Set to "true" to simulate adding PPA (optional, default: false)
# Returns: 0 on success, non-zero on error
ppa_add_repository() {
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

    # Get PPA repository
    local repository
    local exit_code
    repository=$(ppa_get_repository "$manifest_file" "$package_name" 2>&1)
    exit_code=$?

    if [[ "$exit_code" -ne 0 ]]; then
        echo "$repository" >&2
        return "$exit_code"
    fi

    # Check if already added
    if ppa_check_added "$repository"; then
        echo "PPA repository '$repository' is already added"
        return 0
    fi

    # Get GPG key if present
    local gpg_key
    gpg_key=$(ppa_get_gpg_key "$manifest_file" "$package_name")

    # Add PPA
    if [[ "$dry_run" = "true" ]]; then
        echo "[DRY RUN] Would add PPA repository: $repository"
        echo "[DRY RUN] Command: sudo add-apt-repository -y $repository"
        if [[ -n "$gpg_key" ]]; then
            echo "[DRY RUN] Would add GPG key: $gpg_key"
            echo "[DRY RUN] Command: wget -qO - $gpg_key | sudo apt-key add -"
        fi
        return 0
    else
        echo "Adding PPA repository: $repository"

        # Add GPG key first if present
        if [[ -n "$gpg_key" ]]; then
            echo "Adding GPG key: $gpg_key"
            wget -qO - "$gpg_key" | sudo apt-key add -
        fi

        # Add the PPA
        sudo add-apt-repository -y "$repository"
        return $?
    fi
}

# Install a package from PPA
# Usage: ppa_install_package <manifest_file> <package_name> [dry_run]
# Parameters:
#   - manifest_file: Path to the package manifest
#   - package_name: Name of the package to install (as defined in manifest)
#   - dry_run: Set to "true" to simulate installation (optional, default: false)
# Returns: 0 on success, non-zero on error
ppa_install_package() {
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

    # First, add the PPA repository
    if ! ppa_add_repository "$manifest_file" "$package_name" "$dry_run"; then
        echo "Error: Failed to add PPA repository for '$package_name'" >&2
        return 1
    fi

    # Get package name(s) from manifest
    local ppa_packages
    local exit_code
    ppa_packages=$(ppa_get_package_name "$manifest_file" "$package_name" 2>&1)
    exit_code=$?

    if [[ "$exit_code" -ne 0 ]]; then
        echo "$ppa_packages" >&2
        return "$exit_code"
    fi

    # Convert to array (handle multiple packages)
    local packages_array=()
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && packages_array+=("$pkg")
    done <<< "$ppa_packages"

    # Check if we have any packages to install
    if [[ ${#packages_array[@]} -eq 0 ]]; then
        echo "Error: No packages to install" >&2
        return 1
    fi

    # Install packages
    if [[ "$dry_run" = "true" ]]; then
        echo "[DRY RUN] Would update APT cache: sudo apt-get update"
        echo "[DRY RUN] Would install PPA packages: ${packages_array[*]}"
        echo "[DRY RUN] Command: sudo apt-get install -y ${packages_array[*]}"
        return 0
    else
        echo "Updating APT cache..."
        sudo apt-get update

        echo "Installing PPA packages: ${packages_array[*]}"
        sudo apt-get install -y "${packages_array[@]}"
        return $?
    fi
}
