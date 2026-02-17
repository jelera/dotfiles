#!/usr/bin/env bash
# Package cache layer - Eliminates N+1 query problems
# Pre-fetches all available/installed packages ONCE per backend

# Ensure script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed directly" >&2
    exit 1
fi

# Get the directory where this script is located
_CACHE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source bash version check helper
if [[ -f "${_CACHE_SCRIPT_DIR}/bash-version-check.sh" ]]; then
    # shellcheck source=./bash-version-check.sh
    source "${_CACHE_SCRIPT_DIR}/bash-version-check.sh"
    require_bash4 "cache.sh" || return 1
else
    echo "Error: bash-version-check.sh not found" >&2
    return 1
fi

# Global cache arrays (associative arrays for O(1) lookup)
# Requires Bash 4+ (automatically installed on macOS during setup)
declare -gA APT_INSTALLED_CACHE
declare -gA APT_AVAILABLE_CACHE
declare -gA BREW_INSTALLED_CACHE
declare -gA BREW_AVAILABLE_CACHE
declare -gA BREW_CASK_INSTALLED_CACHE
declare -gA MISE_INSTALLED_CACHE

# Cache initialization flags
export APT_CACHE_INITIALIZED=false
export BREW_CACHE_INITIALIZED=false
export MISE_CACHE_INITIALIZED=false

#
# APT Cache Functions
#

# Initialize APT cache (ONE query per type)
# Populates both installed and available package caches
apt_cache_init() {
    # Skip if already initialized
    if [[ "$APT_CACHE_INITIALIZED" == "true" ]]; then
        return 0
    fi

    # Check if apt is available
    if ! command -v dpkg-query >/dev/null 2>&1; then
        return 1
    fi

    # ONE dpkg-query call for all installed packages
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && APT_INSTALLED_CACHE["$pkg"]=1
    done < <(dpkg-query -W --no-paging -f='${Package}\n' 2>/dev/null)

    # ONE apt-cache call for all available packages
    if command -v apt-cache >/dev/null 2>&1; then
        while IFS= read -r pkg; do
            [[ -n "$pkg" ]] && APT_AVAILABLE_CACHE["$pkg"]=1
        done < <(apt-cache pkgnames 2>/dev/null)
    fi

    APT_CACHE_INITIALIZED=true
    return 0
}

# Check if package exists in APT (O(1) hash lookup)
# Usage: apt_package_exists_cached <package_name>
# Returns: 0 if exists, 1 if not
apt_package_exists_cached() {
    local pkg="$1"
    [[ -z "$pkg" ]] && return 1

    # Initialize cache if needed
    if [[ "$APT_CACHE_INITIALIZED" != "true" ]]; then
        apt_cache_init
    fi

    # O(1) hash lookup
    [[ -n "${APT_AVAILABLE_CACHE[$pkg]}" ]]
}

# Check if package is installed via APT (O(1) hash lookup)
# Usage: apt_is_installed_cached <package_name>
# Returns: 0 if installed, 1 if not
apt_is_installed_cached() {
    local pkg="$1"
    [[ -z "$pkg" ]] && return 1

    # Initialize cache if needed
    if [[ "$APT_CACHE_INITIALIZED" != "true" ]]; then
        apt_cache_init
    fi

    # O(1) hash lookup
    [[ -n "${APT_INSTALLED_CACHE[$pkg]}" ]]
}

# Find similar packages using fuzzy matching
# Usage: apt_find_similar_cached <package_name> [max_results]
# Returns: List of similar packages (one per line)
apt_find_similar_cached() {
    local needle="$1"
    local max_results="${2:-5}"

    [[ -z "$needle" ]] && return 1

    # Initialize cache if needed
    if [[ "$APT_CACHE_INITIALIZED" != "true" ]]; then
        apt_cache_init
    fi

    local alternatives=()

    # Strategy 1: Use apt-cache search (best results)
    if command -v apt-cache >/dev/null 2>&1; then
        # Try exact search first
        local search_results
        search_results=$(apt-cache search "^${needle}$" 2>/dev/null | awk '{print $1}')

        if [[ -z "$search_results" ]]; then
            # Try fuzzy search with the package name
            search_results=$(apt-cache search "$needle" 2>/dev/null | awk '{print $1}')
        fi

        # Add results to alternatives
        while IFS= read -r pkg; do
            [[ -n "$pkg" ]] && alternatives+=("$pkg")
        done <<< "$search_results"
    fi

    # Strategy 2: Common package name transformations
    case "$needle" in
        python-*)
            # python-X → python3-X
            local suffix="${needle#python-}"
            alternatives+=("python3-${suffix}")
            alternatives+=("python3.9-${suffix}")
            alternatives+=("python3.10-${suffix}")
            alternatives+=("python3.11-${suffix}")
            alternatives+=("python3.12-${suffix}")
            ;;
        lib-*)
            # lib-X → libX, libX-dev
            local suffix="${needle#lib-}"
            alternatives+=("lib${suffix}" "lib${suffix}-dev")
            ;;
        *-dev)
            # X-dev → libX-dev
            local base="${needle%-dev}"
            alternatives+=("lib${base}-dev")
            ;;
        *)
            ;;
    esac

    # Strategy 3: Fuzzy search in cache (fallback)
    if [[ ${#alternatives[@]} -lt "$max_results" ]]; then
        # Search in associative array keys
        local pkg
        for pkg in "${!APT_AVAILABLE_CACHE[@]}"; do
            # Match packages containing parts of the needle
            if [[ "$pkg" == *"${needle#*-}"* ]] || [[ "$pkg" == *"$needle"* ]]; then
                alternatives+=("$pkg")
            fi
        done
    fi

    # Filter out non-existent packages and remove duplicates
    local verified_alternatives=()

    # Bash 4+: Use associative array for O(1) lookup
    declare -A seen_packages
    for pkg in "${alternatives[@]}"; do
        # Skip if already seen
        if [[ -n "${seen_packages[$pkg]}" ]]; then
            continue
        fi
        seen_packages[$pkg]=1

        # Verify package exists in cache
        if apt_package_exists_cached "$pkg"; then
            verified_alternatives+=("$pkg")
        fi
    done

    # Prioritize exact matches and close matches
    # Sort by relevance: exact prefix match > contains needle > other
    printf '%s\n' "${verified_alternatives[@]}" | \
        awk -v needle="$needle" '
            BEGIN {
                # Exact match gets highest score
                if ($0 == needle) { print "0 " $0; next }
            }
            # Starts with needle
            $0 ~ "^" needle { print "1 " $0; next }
            # Contains needle
            $0 ~ needle { print "2 " $0; next }
            # Everything else
            { print "3 " $0 }
        ' | sort -n -k1,1 | cut -d' ' -f2- | head -n "$max_results"
}

#
# Homebrew Cache Functions
#

# Initialize Homebrew cache (ONE query per type)
brew_cache_init() {
    # Skip if already initialized
    if [[ "$BREW_CACHE_INITIALIZED" == "true" ]]; then
        return 0
    fi

    # Check if brew is available
    if ! command -v brew >/dev/null 2>&1; then
        return 1
    fi

    # ONE brew list call for all installed formulas
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && BREW_INSTALLED_CACHE["$pkg"]=1
    done < <(brew list --formula -1 2>/dev/null)

    # ONE brew list call for all installed casks
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && BREW_CASK_INSTALLED_CACHE["$pkg"]=1
    done < <(brew list --cask -1 2>/dev/null)

    # ONE brew search call for all available packages
    # Note: This can be slow for large formula sets, so we'll use brew formula/cask commands
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && BREW_AVAILABLE_CACHE["$pkg"]=1
    done < <(brew formulae 2>/dev/null)

    BREW_CACHE_INITIALIZED=true
    return 0
}

# Check if package exists in Homebrew (O(1) hash lookup)
brew_package_exists_cached() {
    local pkg="$1"
    [[ -z "$pkg" ]] && return 1

    # Initialize cache if needed
    if [[ "$BREW_CACHE_INITIALIZED" != "true" ]]; then
        brew_cache_init
    fi

    [[ -n "${BREW_AVAILABLE_CACHE[$pkg]}" ]]
}

# Check if package is installed via Homebrew (formula) - O(1) hash lookup
brew_is_installed_cached() {
    local pkg="$1"
    [[ -z "$pkg" ]] && return 1

    # Initialize cache if needed
    if [[ "$BREW_CACHE_INITIALIZED" != "true" ]]; then
        brew_cache_init
    fi

    [[ -n "${BREW_INSTALLED_CACHE[$pkg]}" ]]
}

# Check if cask is installed via Homebrew - O(1) hash lookup
brew_cask_is_installed_cached() {
    local pkg="$1"
    [[ -z "$pkg" ]] && return 1

    # Initialize cache if needed
    if [[ "$BREW_CACHE_INITIALIZED" != "true" ]]; then
        brew_cache_init
    fi

    [[ -n "${BREW_CASK_INSTALLED_CACHE[$pkg]}" ]]
}

# Find similar Homebrew packages
brew_find_similar_cached() {
    local needle="$1"
    local max_results="${2:-5}"

    [[ -z "$needle" ]] && return 1

    # Initialize cache if needed
    if [[ "$BREW_CACHE_INITIALIZED" != "true" ]]; then
        brew_cache_init
    fi

    local alternatives=()

    # Strategy 1: Use brew search (best results, includes fuzzy matching)
    if command -v brew >/dev/null 2>&1; then
        # brew search does fuzzy matching by default
        local search_results
        search_results=$(brew search "$needle" 2>/dev/null)

        # Add results (brew search returns formulas and casks)
        while IFS= read -r pkg; do
            # Skip empty lines and section headers
            if [[ -n "$pkg" ]] && [[ "$pkg" != "==> "* ]]; then
                alternatives+=("$pkg")
            fi
        done <<< "$search_results"
    fi

    # Strategy 2: Common transformations
    case "$needle" in
        *-cli)
            # X-cli might just be X
            local base="${needle%-cli}"
            alternatives+=("$base")
            ;;
        *)
            # Try adding common suffixes
            alternatives+=("${needle}-cli")
            ;;
    esac

    # Strategy 3: Fuzzy search in cache (fallback)
    if [[ ${#alternatives[@]} -lt "$max_results" ]]; then
        local pkg
        for pkg in "${!BREW_AVAILABLE_CACHE[@]}"; do
            if [[ "$pkg" == *"$needle"* ]]; then
                alternatives+=("$pkg")
            fi
        done
    fi

    # Filter out non-existent packages and remove duplicates
    local verified_alternatives=()

    # Bash 4+: Use associative array for O(1) lookup
    declare -A seen_packages
    for pkg in "${alternatives[@]}"; do
        # Skip if already seen
        if [[ -n "${seen_packages[$pkg]}" ]]; then
            continue
        fi
        seen_packages[$pkg]=1

        # For brew, we trust the search results
        verified_alternatives+=("$pkg")
    done

    # Sort by relevance
    printf '%s\n' "${verified_alternatives[@]}" | \
        awk -v needle="$needle" '
            BEGIN {
                # Exact match
                if ($0 == needle) { print "0 " $0; next }
            }
            # Starts with needle
            $0 ~ "^" needle { print "1 " $0; next }
            # Contains needle
            $0 ~ needle { print "2 " $0; next }
            # Everything else
            { print "3 " $0 }
        ' | sort -n -k1,1 | cut -d' ' -f2- | head -n "$max_results"
}

#
# mise Cache Functions
#

# Initialize mise cache
mise_cache_init() {
    # Skip if already initialized
    if [[ "$MISE_CACHE_INITIALIZED" == "true" ]]; then
        return 0
    fi

    # Check if mise is available
    if ! command -v mise >/dev/null 2>&1; then
        return 1
    fi

    # ONE mise list call for all installed tools
    while IFS= read -r line; do
        local tool="${line%%@*}"
        [[ -n "$tool" ]] && MISE_INSTALLED_CACHE["$tool"]=1
    done < <(mise list --installed 2>/dev/null | awk '{print $1}')

    # Note: We don't cache all available mise tools (too slow)
    # Instead, we'll check availability on-demand using mise ls-remote

    MISE_CACHE_INITIALIZED=true
    return 0
}

# Check if tool is installed via mise - O(1) hash lookup
mise_is_installed_cached() {
    local tool="$1"
    [[ -z "$tool" ]] && return 1

    # Initialize cache if needed
    if [[ "$MISE_CACHE_INITIALIZED" != "true" ]]; then
        mise_cache_init
    fi

    [[ -n "${MISE_INSTALLED_CACHE[$tool]}" ]]
}

# Check if tool is available in mise registry (not cached, direct check)
mise_tool_exists() {
    local tool="$1"

    [[ -z "$tool" ]] && return 1

    # Check if mise is available
    if ! command -v mise >/dev/null 2>&1; then
        return 1
    fi

    # Direct check (not cached as registry is too large)
    mise ls-remote "$tool" >/dev/null 2>&1
}

# Find similar mise tools
mise_find_similar() {
    local needle="$1"
    local max_results="${2:-5}"

    [[ -z "$needle" ]] && return 1

    # Check if mise is available
    if ! command -v mise >/dev/null 2>&1; then
        return 1
    fi

    local alternatives=()

    # Strategy 1: Use mise registry search
    # mise doesn't have a direct search, but we can list all plugins and filter
    local search_results
    search_results=$(mise plugins ls-remote 2>/dev/null | grep -i "$needle" | head -n "$max_results")

    while IFS= read -r plugin; do
        # Skip empty lines
        [[ -n "$plugin" ]] && alternatives+=("$plugin")
    done <<< "$search_results"

    # Strategy 2: Common transformations for language tools
    case "$needle" in
        python)
            alternatives+=("python" "python3")
            ;;
        node)
            alternatives+=("node" "nodejs")
            ;;
        ruby)
            alternatives+=("ruby")
            ;;
        *)
            ;;
    esac

    # Remove duplicates
    printf '%s\n' "${alternatives[@]}" | sort -u | head -n "$max_results"
}

#
# Utility Functions
#

# Clear all caches (useful for testing or re-initialization)
cache_clear_all() {
    unset APT_INSTALLED_CACHE APT_AVAILABLE_CACHE
    unset BREW_INSTALLED_CACHE BREW_AVAILABLE_CACHE BREW_CASK_INSTALLED_CACHE
    unset MISE_INSTALLED_CACHE

    declare -gA APT_INSTALLED_CACHE
    declare -gA APT_AVAILABLE_CACHE
    declare -gA BREW_INSTALLED_CACHE
    declare -gA BREW_AVAILABLE_CACHE
    declare -gA BREW_CASK_INSTALLED_CACHE
    declare -gA MISE_INSTALLED_CACHE

    APT_CACHE_INITIALIZED=false
    BREW_CACHE_INITIALIZED=false
    MISE_CACHE_INITIALIZED=false
}

# Get cache statistics
cache_stats() {
    echo "Cache Statistics:"
    echo ""
    echo "Bash Version: ${BASH_VERSION}"
    echo ""

    if [[ "$APT_CACHE_INITIALIZED" == "true" ]]; then
        echo "APT:"
        echo "  Installed packages: ${#APT_INSTALLED_CACHE[@]}"
        echo "  Available packages: ${#APT_AVAILABLE_CACHE[@]}"
    else
        echo "APT: Not initialized"
    fi
    echo ""

    if [[ "$BREW_CACHE_INITIALIZED" == "true" ]]; then
        echo "Homebrew:"
        echo "  Installed formulas: ${#BREW_INSTALLED_CACHE[@]}"
        echo "  Installed casks: ${#BREW_CASK_INSTALLED_CACHE[@]}"
        echo "  Available packages: ${#BREW_AVAILABLE_CACHE[@]}"
    else
        echo "Homebrew: Not initialized"
    fi
    echo ""

    if [[ "$MISE_CACHE_INITIALIZED" == "true" ]]; then
        echo "mise:"
        echo "  Installed tools: ${#MISE_INSTALLED_CACHE[@]}"
    else
        echo "mise: Not initialized"
    fi
}
