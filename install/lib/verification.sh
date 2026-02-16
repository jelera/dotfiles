#!/usr/bin/env bash
# Package verification layer - Batch verification with fuzzy matching
# Verifies all packages at once using cache, no N+1 queries

# Ensure script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed directly" >&2
    exit 1
fi

# Get the directory where this script is located
VERIFICATION_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source cache module if not already loaded
if ! command -v apt_cache_init >/dev/null 2>&1; then
    if [[ -f "${VERIFICATION_SCRIPT_DIR}/cache.sh" ]]; then
        # shellcheck source=./cache.sh
        source "${VERIFICATION_SCRIPT_DIR}/cache.sh"
    else
        echo "Error: cache.sh not found" >&2
        return 1
    fi
fi

# Global array to store verification issues
# Note: Bash 3.x doesn't support -g flag, but top-level arrays are global when sourced
declare -a VERIFICATION_ISSUES
VERIFICATION_ISSUES=()

# Issue format: "backend:pkg_name:actual_pkg:status:alternatives"
# status: MISSING (not found), FUZZY (alternatives available), OK (verified)

# Verify a single APT package
# Usage: verify_apt_package <manifest_file> <package_name>
# Returns: 0 if OK, adds to VERIFICATION_ISSUES if not
verify_apt_package() {
    local manifest_file="$1"
    local package_name="$2"

    # Get APT package name from manifest
    local apt_pkg
    if ! apt_pkg=$(apt_get_package_name "$manifest_file" "$package_name" 2>/dev/null); then
        # No APT config - not an error, just skip
        return 0
    fi

    # Check if package exists in cache
    if apt_package_exists_cached "$apt_pkg"; then
        return 0  # OK
    fi

    # Package not found - try fuzzy matching
    local alternatives
    alternatives=$(apt_find_similar_cached "$apt_pkg" 5)

    if [[ -n "$alternatives" ]]; then
        # Found alternatives
        local alts_joined
        alts_joined=$(echo "$alternatives" | tr '\n' '|' | sed 's/|$//')
        VERIFICATION_ISSUES+=("apt:${package_name}:${apt_pkg}:FUZZY:${alts_joined}")
    else
        # No alternatives found
        VERIFICATION_ISSUES+=("apt:${package_name}:${apt_pkg}:MISSING:")
    fi

    return 1
}

# Verify a single Homebrew package
verify_brew_package() {
    local manifest_file="$1"
    local package_name="$2"

    # Get Homebrew package name from manifest
    if ! brew_get_package_name "$manifest_file" "$package_name" >/dev/null 2>&1; then
        # No Homebrew config - skip
        return 0
    fi

    # Check if it's a cask (not used yet, but logic is here for future)
    if brew_is_cask "$manifest_file" "$package_name" >/dev/null 2>&1; then
        : # is_cask="true"
    fi

    # For now, we'll trust Homebrew packages exist
    # brew formulae output is too large to search efficiently
    # Instead, we'll just verify during installation
    return 0
}

# Verify a single mise tool
verify_mise_tool() {
    local manifest_file="$1"
    local package_name="$2"

    # Check if package is managed by mise
    if ! mise_is_managed "$manifest_file" "$package_name" 2>/dev/null; then
        return 0
    fi

    # Check if tool is available in mise registry
    if ! mise_tool_exists "$package_name"; then
        # Try to find similar tools
        local alternatives
        if command -v mise_find_similar >/dev/null 2>&1; then
            alternatives=$(mise_find_similar "$package_name" 5)
        fi

        if [[ -n "$alternatives" ]]; then
            local alts_joined
            alts_joined=$(echo "$alternatives" | tr '\n' '|' | sed 's/|$//')
            VERIFICATION_ISSUES+=("mise:${package_name}:${package_name}:FUZZY:${alts_joined}")
        else
            VERIFICATION_ISSUES+=("mise:${package_name}:${package_name}:MISSING:")
        fi
        return 1
    fi

    return 0
}

# Verify a single PPA package
verify_ppa_package() {
    local manifest_file="$1"
    local package_name="$2"

    # Get PPA config
    local ppa_repo
    if ! ppa_repo=$(ppa_get_repository "$manifest_file" "$package_name" 2>/dev/null); then
        # No PPA config - skip
        return 0
    fi

    # Get package names
    local ppa_packages
    if ! ppa_packages=$(ppa_get_package_name "$manifest_file" "$package_name" 2>/dev/null); then
        VERIFICATION_ISSUES+=("ppa:${package_name}:${ppa_repo}:MISSING:")
        return 1
    fi

    # Verify the repo format is correct
    if [[ ! "$ppa_repo" =~ ^ppa: ]]; then
        VERIFICATION_ISSUES+=("ppa:${package_name}:${ppa_repo}:MISSING:Invalid PPA format")
        return 1
    fi

    # Note: PPA packages can only be fully verified after the repository is added
    # We could check if the PPA is already added and verify the package then
    if command -v ppa_check_added >/dev/null 2>&1; then
        if ppa_check_added "$ppa_repo"; then
            # PPA is already added, we can verify the package exists
            # Convert package list to array and check each
            while IFS= read -r apt_pkg; do
                [[ -z "$apt_pkg" ]] && continue

                if ! apt_package_exists_cached "$apt_pkg"; then
                    # Package not found, try to find similar
                    local alternatives
                    alternatives=$(apt_find_similar_cached "$apt_pkg" 5)

                    if [[ -n "$alternatives" ]]; then
                        local alts_joined
                        alts_joined=$(echo "$alternatives" | tr '\n' '|' | sed 's/|$//')
                        VERIFICATION_ISSUES+=("ppa:${package_name}:${apt_pkg}:FUZZY:${alts_joined}")
                    else
                        VERIFICATION_ISSUES+=("ppa:${package_name}:${apt_pkg}:MISSING:")
                    fi
                    return 1
                fi
            done <<< "$ppa_packages"
        fi
    fi

    return 0
}

# Verify all packages for a given backend at once
# Usage: verify_packages_for_backend <manifest_file> <backend> <package_list>
# package_list is space-separated string of package names
verify_packages_for_backend() {
    local manifest_file="$1"
    local backend="$2"
    local package_list="$3"

    [[ -z "$package_list" ]] && return 0

    # Initialize cache for this backend
    case "$backend" in
        apt)
            apt_cache_init
            ;;
        homebrew)
            brew_cache_init
            ;;
        mise)
            mise_cache_init
            ;;
        ppa)
            # PPA uses APT cache
            apt_cache_init
            ;;
        *)
            ;;
    esac

    # Convert space-separated list to array
    local packages_array
    # shellcheck disable=SC2206
    packages_array=($package_list)

    # Verify each package (using cache, no subprocess calls)
    local pkg
    for pkg in "${packages_array[@]}"; do
        [[ -z "$pkg" ]] && continue

        case "$backend" in
            apt)
                verify_apt_package "$manifest_file" "$pkg"
                ;;
            homebrew)
                verify_brew_package "$manifest_file" "$pkg"
                ;;
            mise)
                verify_mise_tool "$manifest_file" "$pkg"
                ;;
            ppa)
                verify_ppa_package "$manifest_file" "$pkg"
                ;;
            *)
                ;;
        esac
    done

    return 0
}

# Verify all packages in batch
# Usage: verify_packages_batch <manifest_file> <apt_pkgs> <brew_pkgs> <mise_pkgs> <ppa_pkgs>
verify_packages_batch() {
    local manifest_file="$1"
    local apt_pkgs="$2"
    local brew_pkgs="$3"
    local mise_pkgs="$4"
    local ppa_pkgs="$5"

    # Clear previous issues
    VERIFICATION_ISSUES=()

    # Verify packages for each backend
    [[ -n "$apt_pkgs" ]] && verify_packages_for_backend "$manifest_file" "apt" "$apt_pkgs"
    [[ -n "$brew_pkgs" ]] && verify_packages_for_backend "$manifest_file" "homebrew" "$brew_pkgs"
    [[ -n "$mise_pkgs" ]] && verify_packages_for_backend "$manifest_file" "mise" "$mise_pkgs"
    [[ -n "$ppa_pkgs" ]] && verify_packages_for_backend "$manifest_file" "ppa" "$ppa_pkgs"

    # Return 0 if no issues, 1 if issues found
    [[ ${#VERIFICATION_ISSUES[@]} -eq 0 ]]
}

# Get verification issues count
get_verification_issues_count() {
    echo "${#VERIFICATION_ISSUES[@]}"
}

# Get verification issues
get_verification_issues() {
    printf '%s\n' "${VERIFICATION_ISSUES[@]}"
}

# Check if there are any verification issues
has_verification_issues() {
    [[ ${#VERIFICATION_ISSUES[@]} -gt 0 ]]
}

# Parse a verification issue
# Usage: parse_verification_issue <issue_string>
# Returns: Sets global variables ISSUE_BACKEND, ISSUE_PKG, ISSUE_ACTUAL, ISSUE_STATUS, ISSUE_ALTS
parse_verification_issue() {
    local issue="$1"

    # Parse format: "backend:pkg_name:actual_pkg:status:alternatives"
    IFS=: read -r ISSUE_BACKEND ISSUE_PKG ISSUE_ACTUAL ISSUE_STATUS ISSUE_ALTS <<< "$issue"

    export ISSUE_BACKEND ISSUE_PKG ISSUE_ACTUAL ISSUE_STATUS ISSUE_ALTS
}

# Format verification issues for display
format_verification_issues() {
    local issues_count="${#VERIFICATION_ISSUES[@]}"

    if [[ "$issues_count" -eq 0 ]]; then
        echo "✅ All packages verified successfully"
        return 0
    fi

    echo ""
    echo "⚠️  Found ${issues_count} package(s) that need attention:"
    echo ""

    local issue
    for issue in "${VERIFICATION_ISSUES[@]}"; do
        parse_verification_issue "$issue"

        case "$ISSUE_STATUS" in
            MISSING)
                echo "  ❌ ${ISSUE_PKG} (${ISSUE_BACKEND}): '${ISSUE_ACTUAL}' not found"
                ;;
            FUZZY)
                echo "  🔍 ${ISSUE_PKG} (${ISSUE_BACKEND}): '${ISSUE_ACTUAL}' not found"
                echo "     Alternatives available: ${ISSUE_ALTS//|/, }"
                ;;
            *)
                ;;
        esac
    done

    echo ""
}

# Log missing packages to JSON file
# Usage: log_missing_packages [log_file]
log_missing_packages() {
    local log_file="${1:-}"

    # Auto-generate log file if not provided
    if [[ -z "$log_file" ]]; then
        local log_dir="${HOME}/.dotfiles-install-logs"
        mkdir -p "$log_dir"
        log_file="${log_dir}/missing-packages-$(date +%Y%m%d_%H%M%S).json"
    fi

    # Check if we have jq for JSON formatting
    if ! command -v jq >/dev/null 2>&1; then
        echo "Warning: jq not found, logging as plain text" >&2
        printf '%s\n' "${VERIFICATION_ISSUES[@]}" > "$log_file"
        echo "Missing packages logged to: $log_file"
        return 0
    fi

    # Build JSON array
    local json_array="[]"
    local issue
    for issue in "${VERIFICATION_ISSUES[@]}"; do
        parse_verification_issue "$issue"

        # Split alternatives into array
        local alts_array="[]"
        if [[ -n "$ISSUE_ALTS" ]]; then
            alts_array=$(printf '%s\n' "${ISSUE_ALTS//|/$'\n'}" | jq -R . | jq -s .)
        fi

        # Add to JSON array
        json_array=$(echo "$json_array" | jq \
            --arg backend "$ISSUE_BACKEND" \
            --arg pkg "$ISSUE_PKG" \
            --arg actual "$ISSUE_ACTUAL" \
            --arg status "$ISSUE_STATUS" \
            --argjson alts "$alts_array" \
            '. += [{
                backend: $backend,
                package: $pkg,
                actual_name: $actual,
                status: $status,
                alternatives: $alts
            }]')
    done

    # Create final JSON document
    jq -n \
        --arg date "$(date -Iseconds)" \
        --arg user "$(whoami)" \
        --arg host "$(hostname)" \
        --argjson packages "$json_array" \
        '{
            date: $date,
            user: $user,
            host: $host,
            packages: $packages
        }' > "$log_file"

    echo "Missing packages logged to: $log_file"
    echo "Retry with: ./install.sh --retry-missing $log_file"
}

# Load missing packages from log file
# Usage: load_missing_packages <log_file>
# Returns: Prints package names (one per line)
load_missing_packages() {
    local log_file="$1"

    if [[ ! -f "$log_file" ]]; then
        echo "Error: Log file not found: $log_file" >&2
        return 1
    fi

    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq not found, cannot parse JSON log file" >&2
        return 1
    fi

    # Extract package names from JSON
    jq -r '.packages[].package' "$log_file"
}

# Export functions for use in other scripts
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f verify_apt_package
    export -f verify_brew_package
    export -f verify_mise_tool
    export -f verify_ppa_package
    export -f verify_packages_for_backend
    export -f verify_packages_batch
    export -f get_verification_issues_count
    export -f get_verification_issues
    export -f has_verification_issues
    export -f parse_verification_issue
    export -f format_verification_issues
    export -f log_missing_packages
    export -f load_missing_packages
fi
