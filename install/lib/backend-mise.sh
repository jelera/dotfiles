#!/usr/bin/env bash
# mise tool manager backend
# Provides manifest-aware tool installation via mise

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

# Check if a package is managed by mise
# Usage: mise_is_managed <manifest_file> <package_name>
# Returns: 0 if managed by mise, 1 otherwise
mise_is_managed() {
    local manifest_file="$1"
    local package_name="$2"

    # Validate parameters
    if [[ -z "$manifest_file" ]] || [[ -z "$package_name" ]]; then
        return 1
    fi

    # Check if manifest file exists
    if [[ ! -f "$manifest_file" ]]; then
        return 1
    fi

    # Use the manifest parser function
    is_managed_by_mise "$manifest_file" "$package_name"
}

# Check if mise command is available
# Usage: mise_check_available
# Returns: 0 if available, 1 otherwise
mise_check_available() {
    command -v mise >/dev/null 2>&1
}

# Check if a tool is available in mise registry
# Usage: mise_check_tool_available <tool_name>
# Returns: 0 if available, 1 otherwise
mise_check_tool_available() {
    local tool_name="$1"

    if [[ -z "$tool_name" ]]; then
        return 1
    fi

    # Check if mise is available
    if ! mise_check_available; then
        return 1
    fi

    # Check if tool is in mise registry
    mise ls-remote "$tool_name" >/dev/null 2>&1
}

# Check if a tool is installed via mise
# Usage: mise_check_installed <tool_name>
# Returns: 0 if installed, 1 otherwise
mise_check_installed() {
    local tool_name="$1"

    if [[ -z "$tool_name" ]]; then
        return 1
    fi

    # Check if mise is available
    if ! mise_check_available; then
        return 1
    fi

    # Check if tool is installed (not just listed, but actually installed)
    # A tool is installed if it appears in mise list without "(missing)" marker
    local list_output
    list_output=$(mise list "$tool_name" 2>/dev/null)

    # Check if the tool is listed AND not marked as missing
    if echo "$list_output" | grep -q "$tool_name"; then
        # If it contains "(missing)", then it's not actually installed
        if echo "$list_output" | grep -q "(missing)"; then
            return 1
        fi
        return 0
    fi

    return 1
}

# Get version to install for a tool
# Usage: mise_get_version <manifest_file> <package_name>
# Returns: Version string (defaults to "latest")
mise_get_version() {
    local manifest_file="$1"
    local package_name="$2"

    # Try to get explicit version from manifest
    local version
    version=$(yq eval ".packages.${package_name}.mise_version // \"latest\"" "$manifest_file" 2>/dev/null)

    if [[ -z "$version" ]] || [[ "$version" = "null" ]]; then
        echo "latest"
    else
        echo "$version"
    fi
}

# Install a tool using mise
# Usage: mise_install_tool <manifest_file> <package_name> [dry_run]
# Parameters:
#   - manifest_file: Path to the package manifest
#   - package_name: Name of the package/tool to install
#   - dry_run: Set to "true" to simulate installation (optional, default: false)
# Returns: 0 on success, non-zero on error
mise_install_tool() {
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

    # Check if package is managed by mise
    if ! mise_is_managed "$manifest_file" "$package_name"; then
        echo "Error: Package '$package_name' is not managed by mise" >&2
        return 1
    fi

    # Check if mise is available
    if ! mise_check_available; then
        echo "Warning: mise command not available, skipping '$package_name'" >&2
        return 1
    fi

    # Get version to install
    local version
    version=$(mise_get_version "$manifest_file" "$package_name")

    # Check if already installed
    if mise_check_installed "$package_name"; then
        echo "Tool '$package_name' is already installed via mise"
        return 0
    fi

    # Install tool
    if [[ "$dry_run" = "true" ]]; then
        echo "[DRY RUN] Would install mise tool: $package_name@$version"
        echo "[DRY RUN] Command: mise install $package_name@$version"
        return 0
    else
        echo "Installing mise tool: $package_name@$version"
        mise install "$package_name@$version"
        return $?
    fi
}

# Sync mise tools with manifest for a given category
# Usage: mise_sync_with_manifest <manifest_file> <category> [dry_run]
# Parameters:
#   - manifest_file: Path to the package manifest
#   - category: Category to sync (e.g., "language_runtimes")
#   - dry_run: Set to "true" to simulate sync (optional, default: false)
# Returns: 0 on success
mise_sync_with_manifest() {
    local manifest_file="$1"
    local category="$2"
    local dry_run="${3:-false}"

    # Get all packages in the category that are managed by mise
    local packages
    packages=$(get_packages_by_category "$manifest_file" "$category" 2>/dev/null)

    if [[ -z "$packages" ]]; then
        echo "No packages found in category '$category'"
        return 0
    fi

    # Track statistics
    local total=0
    local succeeded=0
    local failed=0

    # Process each package
    while IFS= read -r package_name; do
        [[ -z "$package_name" ]] && continue

        # Skip if not managed by mise
        if ! mise_is_managed "$manifest_file" "$package_name"; then
            continue
        fi

        ((total++))

        # Try to install the tool
        if [[ "$dry_run" = "true" ]]; then
            echo "[DRY RUN] Would sync mise tool: $package_name"
            ((succeeded++))
        else
            if mise_install_tool "$manifest_file" "$package_name" "false" 2>&1; then
                ((succeeded++))
            else
                echo "Failed to install mise tool: $package_name" >&2
                ((failed++))
            fi
        fi
    done <<< "$packages"

    # Print summary if we processed any packages
    if [[ "$total" -gt 0 ]]; then
        echo ""
        echo "Mise sync summary for '$category':"
        echo "  Total tools: $total"
        echo "  Succeeded: $succeeded"
        echo "  Failed: $failed"
    fi

    return 0
}
