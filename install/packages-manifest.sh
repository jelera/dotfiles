#!/usr/bin/env bash
# Manifest-driven package installation orchestration
# Coordinates multiple package managers using manifest definitions

# This script can be both sourced (for functions) or executed (for CLI)

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source manifest parser if not already loaded
if ! command -v parse_manifest >/dev/null 2>&1; then
    if [ -f "${SCRIPT_DIR}/lib/manifest-parser.sh" ]; then
        # shellcheck source=./lib/manifest-parser.sh
        source "${SCRIPT_DIR}/lib/manifest-parser.sh"
    else
        echo "Error: manifest-parser.sh not found" >&2
        return 1
    fi
fi

# Source all backend modules
for backend in "${SCRIPT_DIR}"/lib/backend-*.sh; do
    if [ -f "$backend" ]; then
        # shellcheck source=./lib/backend-apt.sh
        # shellcheck source=./lib/backend-homebrew.sh
        # shellcheck source=./lib/backend-ppa.sh
        # shellcheck source=./lib/backend-mise.sh
        source "$backend"
    fi
done

# Default manifest location
DEFAULT_MANIFEST="${SCRIPT_DIR}/manifests/packages.yaml"

# Detect current platform
# Returns: ubuntu, macos, or linux
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            echo "ubuntu"
        else
            echo "linux"
        fi
    else
        echo "linux"
    fi
}

# Get all packages for a given profile
# Usage: get_profile_packages <manifest_file> <profile>
# Returns: List of package names (one per line)
get_profile_packages() {
    local manifest_file="$1"
    local profile="$2"

    # Validate parameters
    if [ -z "$manifest_file" ] || [ -z "$profile" ]; then
        echo "Error: Missing required parameters" >&2
        return 1
    fi

    # Get packages for profile (already filters by platform)
    local packages
    packages=$(get_packages_for_profile "$manifest_file" "$profile" 2>&1)
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "Error: Profile '$profile' not found or invalid" >&2
        return 1
    fi

    echo "$packages"
}

# Resolve which backend to use for a package
# Usage: resolve_package_backend <manifest_file> <package_name>
# Returns: Backend name (apt, homebrew, ppa, mise, etc.)
resolve_package_backend() {
    local manifest_file="$1"
    local package_name="$2"

    # Validate parameters
    if [ -z "$manifest_file" ] || [ -z "$package_name" ]; then
        echo "Error: Missing required parameters" >&2
        return 1
    fi

    # Check if package is managed by mise
    if is_managed_by_mise "$manifest_file" "$package_name" 2>/dev/null; then
        echo "mise"
        return 0
    fi

    # Get priority chain for the package
    local priority_chain
    priority_chain=$(get_package_priority "$manifest_file" "$package_name" 2>/dev/null)

    if [ -z "$priority_chain" ]; then
        echo "Error: No priority chain for package '$package_name'" >&2
        return 1
    fi

    # Detect current platform
    local platform
    platform=$(detect_platform)

    # Try each backend in priority order
    while IFS= read -r backend; do
        [ -z "$backend" ] && continue

        # Check if backend is available and package has config for it
        case "$backend" in
            apt)
                if command -v apt-get >/dev/null 2>&1; then
                    if apt_get_package_name "$manifest_file" "$package_name" >/dev/null 2>&1; then
                        echo "apt"
                        return 0
                    fi
                fi
                ;;
            homebrew|homebrew-cask)
                if command -v brew >/dev/null 2>&1; then
                    if brew_get_package_name "$manifest_file" "$package_name" >/dev/null 2>&1; then
                        echo "homebrew"
                        return 0
                    fi
                fi
                ;;
            ppa)
                if [ "$platform" = "ubuntu" ] && command -v add-apt-repository >/dev/null 2>&1; then
                    if ppa_get_repository "$manifest_file" "$package_name" >/dev/null 2>&1; then
                        echo "ppa"
                        return 0
                    fi
                fi
                ;;
            mise)
                if mise_check_available; then
                    if mise_is_managed "$manifest_file" "$package_name"; then
                        echo "mise"
                        return 0
                    fi
                fi
                ;;
        esac
    done <<< "$priority_chain"

    echo "Error: No available backend for package '$package_name'" >&2
    return 1
}

# Install a package using a specific backend
# Usage: install_package_with_backend <manifest_file> <package_name> <backend> [dry_run]
install_package_with_backend() {
    local manifest_file="$1"
    local package_name="$2"
    local backend="$3"
    local dry_run="${4:-false}"

    # Validate parameters
    if [ -z "$manifest_file" ] || [ -z "$package_name" ] || [ -z "$backend" ]; then
        echo "Error: Missing required parameters" >&2
        return 1
    fi

    # Call the appropriate backend function
    case "$backend" in
        apt)
            apt_install_package "$manifest_file" "$package_name" "$dry_run"
            ;;
        homebrew)
            brew_install_package "$manifest_file" "$package_name" "$dry_run"
            ;;
        ppa)
            ppa_install_package "$manifest_file" "$package_name" "$dry_run"
            ;;
        mise)
            mise_install_tool "$manifest_file" "$package_name" "$dry_run"
            ;;
        *)
            echo "Error: Unsupported backend '$backend'" >&2
            return 1
            ;;
    esac
}

# Main installation function from manifest
# Usage: install_from_manifest <manifest_file> <profile> [dry_run]
install_from_manifest() {
    local manifest_file="$1"
    local profile="$2"
    local dry_run="${3:-false}"

    # Validate parameters
    if [ -z "$manifest_file" ]; then
        echo "Error: Missing manifest file parameter" >&2
        return 1
    fi

    if [ -z "$profile" ]; then
        echo "Error: Missing profile parameter" >&2
        return 1
    fi

    # Check if manifest exists
    if [ ! -f "$manifest_file" ]; then
        echo "Error: Manifest file not found: $manifest_file" >&2
        return 1
    fi

    # Validate manifest can be parsed
    if ! validate_manifest "$manifest_file" >/dev/null 2>&1; then
        echo "Error: Invalid or corrupted manifest file" >&2
        return 1
    fi

    # Validate manifest schema
    echo "Validating manifest schema..."
    if ! validate_manifest_schema "$manifest_file" >/dev/null 2>&1; then
        echo "Warning: Manifest schema validation failed, continuing anyway..."
    fi

    echo "Installing packages for profile: $profile"
    if [ "$dry_run" = "true" ]; then
        echo "[DRY RUN MODE - No packages will actually be installed]"
    fi
    echo ""

    # Get packages for profile
    local packages
    packages=$(get_profile_packages "$manifest_file" "$profile")
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "Error: Failed to get packages for profile '$profile'" >&2
        return 1
    fi

    if [ -z "$packages" ]; then
        echo "No packages found for profile '$profile'"
        return 0
    fi

    # Track statistics
    local total=0
    local succeeded=0
    local skipped=0
    local failed=0

    # Process each package
    while IFS= read -r package_name; do
        [ -z "$package_name" ] && continue

        ((total++))

        echo "[$total] Processing package: $package_name"

        # Resolve backend
        local backend
        backend=$(resolve_package_backend "$manifest_file" "$package_name" 2>&1)
        local resolve_status=$?

        if [ $resolve_status -ne 0 ]; then
            echo "  ⚠️  Skipping (no available backend): $package_name"
            echo "      Reason: $backend"
            ((skipped++))
            continue
        fi

        echo "  → Backend: $backend"

        # Install package
        if install_package_with_backend "$manifest_file" "$package_name" "$backend" "$dry_run" 2>&1; then
            echo "  ✅ Success: $package_name"
            ((succeeded++))
        else
            echo "  ❌ Failed: $package_name"
            ((failed++))
        fi

        echo ""
    done <<< "$packages"

    # Print summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Installation Summary for profile '$profile':"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Total packages:    $total"
    echo "  ✅ Succeeded:      $succeeded"
    echo "  ⚠️  Skipped:        $skipped"
    echo "  ❌ Failed:         $failed"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Return success if no failures
    [ $failed -eq 0 ]
}

# CLI entry point (if script is called with arguments)
# Usage: bash packages-manifest.sh <profile> [--dry-run] [--manifest=path]
manifest_install_main() {
    local profile="full"
    local dry_run="false"
    local manifest="$DEFAULT_MANIFEST"
    local profile_set=false

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run|-n)
                dry_run="true"
                ;;
            --manifest=*)
                manifest="${1#*=}"
                ;;
            --help|-h)
                echo "Usage: bash packages-manifest.sh [profile] [options]"
                echo ""
                echo "Profiles:"
                echo "  full       - Complete development environment (default)"
                echo "  dev        - Headless development tools"
                echo "  minimal    - Essential CLI tools only"
                echo "  remote     - Remote server setup"
                echo ""
                echo "Options:"
                echo "  --dry-run, -n           Simulate installation without making changes"
                echo "  --manifest=<path>       Use custom manifest file"
                echo "  --help, -h              Show this help message"
                echo ""
                echo "Examples:"
                echo "  bash packages-manifest.sh minimal --dry-run"
                echo "  bash packages-manifest.sh dev"
                echo "  bash packages-manifest.sh --manifest=custom.yaml full"
                echo ""
                return 0
                ;;
            -*)
                echo "Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                return 1
                ;;
            *)
                # First non-option argument is the profile
                if [ "$profile_set" = "false" ]; then
                    profile="$1"
                    profile_set=true
                else
                    echo "Error: Multiple profiles specified" >&2
                    return 1
                fi
                ;;
        esac
        shift
    done

    # Run installation
    install_from_manifest "$manifest" "$profile" "$dry_run"
}

# If script is executed directly (not sourced), run main function
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # Executed directly - run CLI
    manifest_install_main "$@"
fi
