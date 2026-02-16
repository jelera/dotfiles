#!/usr/bin/env bash
# Manifest-driven package installation orchestration
# Coordinates multiple package managers using manifest definitions

# This script can be both sourced (for functions) or executed (for CLI)

# Get the directory where this script is located
# Use _MANIFEST_SCRIPT_DIR to avoid overwriting parent's SCRIPT_DIR
_MANIFEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source manifest parser if not already loaded
if ! command -v parse_manifest >/dev/null 2>&1; then
    if [[ -f "${_MANIFEST_SCRIPT_DIR}/lib/manifest-parser.sh" ]]; then
        # shellcheck source=./lib/manifest-parser.sh
        source "${_MANIFEST_SCRIPT_DIR}/lib/manifest-parser.sh"
    else
        echo "Error: manifest-parser.sh not found" >&2
        return 1
    fi
fi

# Source all backend modules
for backend in "${_MANIFEST_SCRIPT_DIR}"/lib/backend-*.sh; do
    if [[ -f "$backend" ]]; then
        # shellcheck source=./lib/backend-apt.sh
        # shellcheck source=./lib/backend-homebrew.sh
        # shellcheck source=./lib/backend-ppa.sh
        # shellcheck source=./lib/backend-mise.sh
        source "$backend"
    fi
done

# Source optimization modules (cache, verification, interaction)
for module in cache verification interaction; do
    if [[ -f "${_MANIFEST_SCRIPT_DIR}/lib/${module}.sh" ]]; then
        # shellcheck source=./lib/cache.sh
        # shellcheck source=./lib/verification.sh
        # shellcheck source=./lib/interaction.sh
        source "${_MANIFEST_SCRIPT_DIR}/lib/${module}.sh"
    fi
done

# Default manifest directory
DEFAULT_MANIFEST_DIR="${_MANIFEST_SCRIPT_DIR}/manifests"

# Detect current platform
# Returns: ubuntu, macos, or linux
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        # shellcheck disable=SC2154
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
    if [[ -z "$manifest_file" ]] || [[ -z "$profile" ]]; then
        echo "Error: Missing required parameters" >&2
        return 1
    fi

    # Get packages for profile (already filters by platform)
    local packages
    packages=$(get_packages_for_profile "$manifest_file" "$profile" 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
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
    if [[ -z "$manifest_file" ]] || [[ -z "$package_name" ]]; then
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

    if [[ -z "$priority_chain" ]]; then
        echo "Error: No priority chain for package '$package_name'" >&2
        return 1
    fi

    # Detect current platform
    local platform
    platform=$(detect_platform)

    # Try each backend in priority order
    while IFS= read -r backend; do
        [[ -z "$backend" ]] && continue

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
                if [[ "$platform" = "ubuntu" ]] && command -v add-apt-repository >/dev/null 2>&1; then
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
            *)
                # Unknown backend, skip
                continue
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
    if [[ -z "$manifest_file" ]] || [[ -z "$package_name" ]] || [[ -z "$backend" ]]; then
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

# Install packages in bulk using backend-specific bulk functions
# Usage: install_backend_bulk <backend> <manifest_file> <package_list> [dry_run]
install_backend_bulk() {
    local backend="$1"
    local manifest_file="$2"
    local package_list="$3"
    local dry_run="${4:-false}"

    # Skip if no packages
    if [[ -z "$package_list" ]]; then
        return 0
    fi

    # Call the appropriate bulk function
    case "$backend" in
        apt)
            if command -v apt_install_bulk >/dev/null 2>&1; then
                apt_install_bulk "$manifest_file" "$package_list" "$dry_run"
            else
                # Fallback to one-by-one if bulk not available
                local pkg
                for pkg in $package_list; do
                    apt_install_package "$manifest_file" "$pkg" "$dry_run"
                done
            fi
            ;;
        homebrew)
            if command -v brew_install_bulk >/dev/null 2>&1; then
                brew_install_bulk "$manifest_file" "$package_list" "$dry_run"
            else
                # Fallback to one-by-one
                local pkg
                for pkg in $package_list; do
                    brew_install_package "$manifest_file" "$pkg" "$dry_run"
                done
            fi
            ;;
        ppa)
            if command -v ppa_install_bulk >/dev/null 2>&1; then
                ppa_install_bulk "$manifest_file" "$package_list" "$dry_run"
            else
                # Fallback to one-by-one
                local pkg
                for pkg in $package_list; do
                    ppa_install_package "$manifest_file" "$pkg" "$dry_run"
                done
            fi
            ;;
        mise)
            # mise doesn't have bulk install yet, install one-by-one
            local pkg
            for pkg in $package_list; do
                mise_install_tool "$manifest_file" "$pkg" "$dry_run"
            done
            ;;
        *)
            echo "Error: Unsupported backend '$backend'" >&2
            return 1
            ;;
    esac
}

# Legacy installation function (one-by-one processing)
# Usage: install_from_manifest_legacy <manifest_dir> <profile> [dry_run]
install_from_manifest_legacy() {
    local manifest_dir="$1"
    local profile="$2"
    local dry_run="${3:-false}"

    # Detect platform
    local platform
    platform=$(detect_platform)

    # Load and merge manifests
    local manifests
    # shellcheck disable=SC2207
    manifests=($(load_manifests_for_platform "$manifest_dir" "$platform"))

    if [[ ${#manifests[@]} -eq 0 ]]; then
        echo "Error: No manifests found for platform $platform" >&2
        return 1
    fi

    echo "Loading manifests for platform '$platform': ${manifests[*]##*/}"

    local merged_manifest
    merged_manifest=$(merge_manifests "${manifests[@]}")

    local temp_manifest
    temp_manifest=$(mktemp)
    echo "$merged_manifest" > "$temp_manifest"

    if ! validate_manifest "$temp_manifest" >/dev/null 2>&1; then
        echo "Error: Invalid or corrupted merged manifest" >&2
        rm -f "$temp_manifest"
        return 1
    fi

    echo "Installing packages for profile: $profile (LEGACY MODE)"
    if [[ "$dry_run" = "true" ]]; then
        echo "[DRY RUN MODE]"
    fi
    echo ""

    local packages
    packages=$(get_profile_packages "$temp_manifest" "$profile")

    if [[ -z "$packages" ]]; then
        echo "No packages found for profile '$profile'"
        rm -f "$temp_manifest"
        return 0
    fi

    local total=0
    local succeeded=0
    local skipped=0
    local failed=0

    # Process each package one-by-one (legacy behavior)
    while IFS= read -r package_name; do
        [[ -z "$package_name" ]] && continue
        ((total++))

        echo "[$total] Processing package: $package_name"

        local backend
        if ! backend=$(resolve_package_backend "$temp_manifest" "$package_name" 2>&1); then
            echo "  ⚠️  Skipping (no available backend): $package_name"
            ((skipped++))
            continue
        fi

        echo "  → Backend: $backend"

        if install_package_with_backend "$temp_manifest" "$package_name" "$backend" "$dry_run" 2>&1; then
            echo "  ✅ Success: $package_name"
            ((succeeded++))
        else
            echo "  ❌ Failed: $package_name"
            ((failed++))
        fi

        echo ""
    done <<< "$packages"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Installation Summary (Legacy Mode):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Total packages:    $total"
    echo "  ✅ Succeeded:      $succeeded"
    echo "  ⚠️  Skipped:        $skipped"
    echo "  ❌ Failed:         $failed"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    rm -f "$temp_manifest"
    [[ $failed -eq 0 ]]
}

# Main installation function from manifest (OPTIMIZED BATCH VERSION)
# Usage: install_from_manifest <manifest_dir> <profile> [dry_run] [verify_packages] [interactive]
install_from_manifest() {
    local manifest_dir="$1"
    local profile="$2"
    local dry_run="${3:-false}"
    local verify_packages="${4:-true}"  # Enable verification by default
    local interactive="${5:-true}"       # Enable interactive mode by default

    # Validate parameters
    if [[ -z "$manifest_dir" ]]; then
        echo "Error: Missing manifest directory parameter" >&2
        return 1
    fi

    if [[ -z "$profile" ]]; then
        echo "Error: Missing profile parameter" >&2
        return 1
    fi

    # Check if manifest directory exists
    if [[ ! -d "$manifest_dir" ]]; then
        echo "Error: Manifest directory not found: $manifest_dir" >&2
        return 1
    fi

    # Detect platform
    local platform
    platform=$(detect_platform)

    # Load and merge manifests for this platform
    local manifests
    # shellcheck disable=SC2207
    manifests=($(load_manifests_for_platform "$manifest_dir" "$platform"))

    if [[ ${#manifests[@]} -eq 0 ]]; then
        echo "Error: No manifests found for platform $platform" >&2
        return 1
    fi

    echo "Loading manifests for platform '$platform': ${manifests[*]##*/}"

    # Merge manifests
    local merged_manifest
    merged_manifest=$(merge_manifests "${manifests[@]}")

    # Create temp file for merged manifest
    local temp_manifest
    temp_manifest=$(mktemp)
    echo "$merged_manifest" > "$temp_manifest"

    # Validate merged manifest
    if ! validate_manifest "$temp_manifest" >/dev/null 2>&1; then
        echo "Error: Invalid or corrupted merged manifest" >&2
        rm -f "$temp_manifest"
        return 1
    fi

    # Validate manifest schema
    echo "Validating manifest schema..."
    if ! validate_manifest_schema "$temp_manifest" >/dev/null 2>&1; then
        echo "Warning: Manifest schema validation failed, continuing anyway..."
    fi

    echo "Installing packages for profile: $profile"
    if [[ "$dry_run" = "true" ]]; then
        echo "[DRY RUN MODE - No packages will actually be installed]"
    fi
    echo ""

    # Get packages for profile
    local packages
    packages=$(get_profile_packages "$temp_manifest" "$profile")
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo "Error: Failed to get packages for profile '$profile'" >&2
        rm -f "$temp_manifest"
        return 1
    fi

    if [[ -z "$packages" ]]; then
        echo "No packages found for profile '$profile'"
        rm -f "$temp_manifest"
        return 0
    fi

    # Check Bash version for associative array support
    local BASH_VERSION_MAJOR="${BASH_VERSINFO[0]:-3}"
    # local use_batch=true

    if [[ "$BASH_VERSION_MAJOR" -lt 4 ]]; then
        echo "⚠️  Bash 3.x detected - using compatibility mode"
        # We can still use batch mode with the fallback arrays in cache.sh
    fi

    # Phase 1: Group packages by backend
    echo "Phase 1: Analyzing packages..."
    echo ""

    # Use simple variables instead of associative array for Bash 3.x compatibility
    local apt_packages=""
    local homebrew_packages=""
    local mise_packages=""
    local ppa_packages=""

    local total=0
    local backend_resolved=0

    while IFS= read -r package_name; do
        [[ -z "$package_name" ]] && continue

        ((total++))

        # Resolve backend
        local backend
        backend=$(resolve_package_backend "$temp_manifest" "$package_name" 2>/dev/null)
        local resolve_status=$?

        if [[ $resolve_status -ne 0 ]]; then
            echo "  ⚠️  No backend available for: $package_name"
            continue
        fi

        # Add to backend group
        case "$backend" in
            apt)
                apt_packages+="$package_name "
                ;;
            homebrew)
                homebrew_packages+="$package_name "
                ;;
            mise)
                mise_packages+="$package_name "
                ;;
            ppa)
                ppa_packages+="$package_name "
                ;;
            *)
                echo "  ⚠️  Unknown backend: $backend"
                continue
                ;;
        esac

        ((backend_resolved++))

        echo "  ✓ $package_name → $backend"
    done <<< "$packages"

    echo ""
    echo "Grouped $backend_resolved packages into backends:"
    local count
    count=$(echo "$apt_packages" | wc -w | tr -d ' ')
    [[ "$count" -gt 0 ]] && echo "  • apt: $count packages"
    count=$(echo "$homebrew_packages" | wc -w | tr -d ' ')
    [[ "$count" -gt 0 ]] && echo "  • homebrew: $count packages"
    count=$(echo "$mise_packages" | wc -w | tr -d ' ')
    [[ "$count" -gt 0 ]] && echo "  • mise: $count packages"
    count=$(echo "$ppa_packages" | wc -w | tr -d ' ')
    [[ "$count" -gt 0 ]] && echo "  • ppa: $count packages"
    echo ""

    # Phase 2: Verify packages (if enabled)
    if [[ "$verify_packages" == "true" ]] && command -v verify_packages_batch >/dev/null 2>&1; then
        echo "Phase 2: Verifying packages..."
        echo ""

        # Run batch verification (uses cache, no N+1!)
        if ! verify_packages_batch "$temp_manifest" "$apt_packages" "$homebrew_packages" "$mise_packages" "$ppa_packages"; then
            # Handle verification issues
            set_interactive_mode "$interactive"

            if command -v handle_verification_issues >/dev/null 2>&1; then
                handle_verification_issues

                # Update package lists based on user choices
                if command -v should_skip_package >/dev/null 2>&1; then
                    # Update APT packages
                    local updated_apt=""
                    for pkg in $apt_packages; do
                        if should_skip_package "$pkg"; then
                            echo "  ⏭  Skipping: $pkg"
                        elif alt_pkg=$(get_alternative_package "$pkg" 2>/dev/null); then
                            echo "  🔄 Using alternative: $pkg → $alt_pkg"
                            updated_apt+="$alt_pkg "
                        else
                            updated_apt+="$pkg "
                        fi
                    done
                    apt_packages="$updated_apt"

                    # Update Homebrew packages
                    local updated_brew=""
                    for pkg in $homebrew_packages; do
                        if should_skip_package "$pkg"; then
                            echo "  ⏭  Skipping: $pkg"
                        elif alt_pkg=$(get_alternative_package "$pkg" 2>/dev/null); then
                            echo "  🔄 Using alternative: $pkg → $alt_pkg"
                            updated_brew+="$alt_pkg "
                        else
                            updated_brew+="$pkg "
                        fi
                    done
                    homebrew_packages="$updated_brew"

                    # Update mise packages
                    local updated_mise=""
                    for pkg in $mise_packages; do
                        if should_skip_package "$pkg"; then
                            echo "  ⏭  Skipping: $pkg"
                        elif alt_pkg=$(get_alternative_package "$pkg" 2>/dev/null); then
                            echo "  🔄 Using alternative: $pkg → $alt_pkg"
                            updated_mise+="$alt_pkg "
                        else
                            updated_mise+="$pkg "
                        fi
                    done
                    mise_packages="$updated_mise"

                    # Update PPA packages
                    local updated_ppa=""
                    for pkg in $ppa_packages; do
                        if should_skip_package "$pkg"; then
                            echo "  ⏭  Skipping: $pkg"
                        elif alt_pkg=$(get_alternative_package "$pkg" 2>/dev/null); then
                            echo "  🔄 Using alternative: $pkg → $alt_pkg"
                            updated_ppa+="$alt_pkg "
                        else
                            updated_ppa+="$pkg "
                        fi
                    done
                    ppa_packages="$updated_ppa"
                fi
            fi

            echo ""
        else
            echo "✅ All packages verified successfully"
            echo ""
        fi
    else
        echo "Phase 2: Package verification disabled"
        echo ""
    fi

    # Phase 3: Install packages by backend (bulk operations!)
    echo "Phase 3: Installing packages..."
    echo ""

    local succeeded=0
    local failed=0
    local skipped=0

    # Install APT packages
    if [[ -n "$apt_packages" ]]; then
        local pkg_count
        pkg_count=$(echo "$apt_packages" | wc -w | tr -d ' ')
        if [[ "$pkg_count" -gt 0 ]]; then
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Installing via apt ($pkg_count packages)..."
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            if install_backend_bulk "apt" "$temp_manifest" "$apt_packages" "$dry_run"; then
                ((succeeded += pkg_count))
            else
                ((failed += pkg_count))
            fi
            echo ""
        fi
    fi

    # Install Homebrew packages
    if [[ -n "$homebrew_packages" ]]; then
        local pkg_count
        pkg_count=$(echo "$homebrew_packages" | wc -w | tr -d ' ')
        if [[ "$pkg_count" -gt 0 ]]; then
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Installing via homebrew ($pkg_count packages)..."
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            if install_backend_bulk "homebrew" "$temp_manifest" "$homebrew_packages" "$dry_run"; then
                ((succeeded += pkg_count))
            else
                ((failed += pkg_count))
            fi
            echo ""
        fi
    fi

    # Install mise packages
    if [[ -n "$mise_packages" ]]; then
        local pkg_count
        pkg_count=$(echo "$mise_packages" | wc -w | tr -d ' ')
        if [[ "$pkg_count" -gt 0 ]]; then
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Installing via mise ($pkg_count packages)..."
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            if install_backend_bulk "mise" "$temp_manifest" "$mise_packages" "$dry_run"; then
                ((succeeded += pkg_count))
            else
                ((failed += pkg_count))
            fi
            echo ""
        fi
    fi

    # Install PPA packages
    if [[ -n "$ppa_packages" ]]; then
        local pkg_count
        pkg_count=$(echo "$ppa_packages" | wc -w | tr -d ' ')
        if [[ "$pkg_count" -gt 0 ]]; then
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Installing via ppa ($pkg_count packages)..."
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            if install_backend_bulk "ppa" "$temp_manifest" "$ppa_packages" "$dry_run"; then
                ((succeeded += pkg_count))
            else
                ((failed += pkg_count))
            fi
            echo ""
        fi
    fi

    # Print final summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Final Installation Summary for profile '$profile':"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Total packages:    $total"
    echo "  Backend resolved:  $backend_resolved"
    echo "  ✅ Succeeded:      $succeeded"
    echo "  ⚠️  Skipped:        $skipped"
    echo "  ❌ Failed:         $failed"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Show cache statistics if available
    if command -v cache_stats >/dev/null 2>&1 && [[ "$verify_packages" == "true" ]]; then
        echo ""
        cache_stats
    fi

    # Clean up temp manifest
    rm -f "$temp_manifest"

    # Return success if no failures
    [[ $failed -eq 0 ]]
}

# CLI entry point (if script is called with arguments)
# Usage: bash packages-manifest.sh <profile> [options]
manifest_install_main() {
    local profile="full"
    local dry_run="false"
    local manifest_dir="$DEFAULT_MANIFEST_DIR"
    local profile_set=false
    local verify_packages="true"
    local interactive="true"
    local retry_missing=""
    local use_legacy="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run|-n)
                dry_run="true"
                ;;
            --manifest-dir=*)
                manifest_dir="${1#*=}"
                ;;
            --manifest=*)
                # Support old --manifest= for backward compat, treat as directory
                manifest_dir="${1#*=}"
                manifest_dir="${manifest_dir%/*}"  # Remove filename if provided
                ;;
            --verify-packages)
                verify_packages="true"
                ;;
            --no-verify)
                verify_packages="false"
                ;;
            --interactive)
                interactive="true"
                ;;
            --non-interactive)
                interactive="false"
                ;;
            --retry-missing=*)
                retry_missing="${1#*=}"
                ;;
            --use-legacy)
                use_legacy="true"
                ;;
            --cache-stats)
                # Show cache statistics and exit
                if command -v cache_stats >/dev/null 2>&1; then
                    cache_stats
                else
                    echo "Cache module not loaded"
                fi
                return 0
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
                echo "  --dry-run, -n                Simulate installation without making changes"
                echo "  --manifest-dir=<path>        Use custom manifest directory"
                echo "  --verify-packages            Enable package verification (default)"
                echo "  --no-verify                  Disable package verification"
                echo "  --interactive                Prompt for alternatives (default)"
                echo "  --non-interactive            Auto-skip missing packages"
                echo "  --retry-missing=<file>       Retry from missing packages log"
                echo "  --use-legacy                 Use legacy one-by-one installation"
                echo "  --cache-stats                Show cache statistics and exit"
                echo "  --help, -h                   Show this help message"
                echo ""
                echo "Examples:"
                echo "  bash packages-manifest.sh minimal --dry-run"
                echo "  bash packages-manifest.sh dev --non-interactive"
                echo "  bash packages-manifest.sh --no-verify full"
                echo "  bash packages-manifest.sh --retry-missing ~/.dotfiles-install-logs/missing-*.json"
                echo "  bash packages-manifest.sh --cache-stats"
                echo ""
                echo "Performance:"
                echo "  The optimized batch mode reduces subprocess calls by ~20-30x"
                echo "  compared to legacy mode. PPA installations use a single apt-get"
                echo "  update instead of N updates (can save 10+ minutes)."
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
                if [[ "$profile_set" = "false" ]]; then
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

    # Handle retry missing packages
    if [[ -n "$retry_missing" ]]; then
        if [[ ! -f "$retry_missing" ]]; then
            echo "Error: Log file not found: $retry_missing" >&2
            return 1
        fi

        echo "Retrying missing packages from: $retry_missing"
        echo ""

        # Load missing packages
        if command -v load_missing_packages >/dev/null 2>&1; then
            local missing_packages
            missing_packages=$(load_missing_packages "$retry_missing")

            if [[ -z "$missing_packages" ]]; then
                echo "No packages to retry"
                return 0
            fi

            # Create temporary profile with these packages
            # For now, just show the packages
            echo "Missing packages:"
            echo "$missing_packages"
            echo ""
            echo "Note: Retry functionality requires additional implementation"
            return 0
        else
            echo "Error: Verification module not loaded" >&2
            return 1
        fi
    fi

    # Run installation (legacy or optimized)
    if [[ "$use_legacy" == "true" ]]; then
        echo "⚠️  Using legacy installation mode (slower, but compatible)"
        echo ""
        install_from_manifest_legacy "$manifest_dir" "$profile" "$dry_run"
    else
        install_from_manifest "$manifest_dir" "$profile" "$dry_run" "$verify_packages" "$interactive"
    fi
}

# If script is executed directly (not sourced), run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Executed directly - run CLI
    manifest_install_main "$@"
fi
