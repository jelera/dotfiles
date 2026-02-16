#!/usr/bin/env bash
# User interaction layer - Batch prompts for package issues
# Presents all verification issues at once, not one-by-one

# Ensure script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed directly" >&2
    exit 1
fi

# Get the directory where this script is located
INTERACTION_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source verification module if not already loaded
if ! command -v has_verification_issues >/dev/null 2>&1; then
    if [[ -f "${INTERACTION_SCRIPT_DIR}/verification.sh" ]]; then
        # shellcheck source=./verification.sh
        source "${INTERACTION_SCRIPT_DIR}/verification.sh"
    else
        echo "Error: verification.sh not found" >&2
        return 1
    fi
fi

# Check Bash version for associative array support
BASH_VERSION_MAJOR="${BASH_VERSINFO[0]:-3}"

# Global user choices storage
if [[ "$BASH_VERSION_MAJOR" -lt 4 ]]; then
    # Bash 3.x fallback - will use format "pkg=choice" in flat array
    # Note: -g not supported in Bash 3.x, but top-level arrays are global when sourced
    declare -a USER_PACKAGE_CHOICES_ARRAY
    USER_PACKAGE_CHOICES_ARRAY=()
else
    # Bash 4+ - associative array
    declare -gA USER_PACKAGE_CHOICES
fi

# Interactive mode flag
INTERACTIVE_MODE="${INTERACTIVE_MODE:-true}"

# Set interactive mode
set_interactive_mode() {
    local mode="${1:-true}"
    INTERACTIVE_MODE="$mode"
    export INTERACTIVE_MODE
}

# Check if interactive mode is enabled
is_interactive() {
    [[ "$INTERACTIVE_MODE" == "true" ]]
}

# Store user choice for a package
store_user_choice() {
    local pkg="$1"
    local choice="$2"

    if [[ "$BASH_VERSION_MAJOR" -lt 4 ]]; then
        # Bash 3.x: store as "pkg=choice" in array
        USER_PACKAGE_CHOICES_ARRAY+=("${pkg}=${choice}")
    else
        # Bash 4+: use associative array
        USER_PACKAGE_CHOICES["$pkg"]="$choice"
    fi
}

# Get user choice for a package
get_user_choice() {
    local pkg="$1"

    if [[ "$BASH_VERSION_MAJOR" -lt 4 ]]; then
        # Bash 3.x: linear search
        local entry
        for entry in "${USER_PACKAGE_CHOICES_ARRAY[@]}"; do
            if [[ "$entry" == "${pkg}="* ]]; then
                echo "${entry#*=}"
                return 0
            fi
        done
        return 1
    else
        # Bash 4+: hash lookup
        if [[ -n "${USER_PACKAGE_CHOICES[$pkg]}" ]]; then
            echo "${USER_PACKAGE_CHOICES[$pkg]}"
            return 0
        fi
        return 1
    fi
}

# Clear all user choices
clear_user_choices() {
    if [[ "$BASH_VERSION_MAJOR" -lt 4 ]]; then
        USER_PACKAGE_CHOICES_ARRAY=()
    else
        unset USER_PACKAGE_CHOICES
        declare -gA USER_PACKAGE_CHOICES
    fi
}

# Prompt user for a single package issue
# Returns: choice (package name or "SKIP")
prompt_single_package() {
    local pkg="$1"
    local backend="$2"
    local actual_pkg="$3"
    local status="$4"
    local alternatives="$5"

    # Parse alternatives (pipe-separated)
    local -a alt_array
    if [[ -n "$alternatives" ]]; then
        IFS='|' read -ra alt_array <<< "$alternatives"
    fi

    echo ""

    if [[ "$status" == "MISSING" ]]; then
        echo "❌ Package not found: ${pkg} (${backend})"
        echo "   Tried: ${actual_pkg}"
        echo ""
        if [[ -z "$alternatives" ]]; then
            echo "   No alternatives available"
            echo "   [s] Skip this package"
            echo "   [q] Quit installation"
            echo ""
            read -rp "   Choice [s/q]: " choice

            case "$choice" in
                q|Q)
                    echo "Installation cancelled by user"
                    exit 1
                    ;;
                *)
                    echo "SKIP"
                    return 0
                    ;;
            esac
        fi
    fi

    if [[ "$status" == "FUZZY" ]] && [[ ${#alt_array[@]} -gt 0 ]]; then
        echo "🔍 Package not found: ${pkg} (${backend})"
        echo "   Tried: ${actual_pkg}"
        echo ""
        echo "   Available alternatives:"

        local i=1
        for alt in "${alt_array[@]}"; do
            echo "     [$i] $alt"
            ((i++))
        done

        echo "     [s] Skip this package"
        echo "     [q] Quit installation"
        echo ""
        read -rp "   Choose [1-${#alt_array[@]}/s/q]: " choice

        case "$choice" in
            q|Q)
                echo "Installation cancelled by user"
                exit 1
                ;;
            s|S|"")
                echo "SKIP"
                return 0
                ;;
            *)
                # Validate numeric choice
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 && $choice -le ${#alt_array[@]} ]]; then
                    echo "${alt_array[$((choice-1))]}"
                    return 0
                else
                    echo "Invalid choice, skipping package"
                    echo "SKIP"
                    return 0
                fi
                ;;
        esac
    fi

    echo "SKIP"
}

# Handle all verification issues interactively
# Presents all issues and collects user choices in one session
handle_verification_issues_interactive() {
    # Check if there are issues to handle
    if ! has_verification_issues; then
        return 0
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Package Verification Issues"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Get all issues
    local issues
    issues=$(get_verification_issues)

    # Count issues
    local issues_count
    issues_count=$(get_verification_issues_count)

    echo ""
    echo "Found ${issues_count} package(s) that need attention."
    echo "You will be prompted for each package."
    echo ""

    # Clear previous choices
    clear_user_choices

    # Process each issue
    while IFS= read -r issue; do
        [[ -z "$issue" ]] && continue

        # Parse issue
        parse_verification_issue "$issue"

        # Prompt user
        local choice
        # shellcheck disable=SC2154
        choice=$(prompt_single_package \
            "$ISSUE_PKG" \
            "$ISSUE_BACKEND" \
            "$ISSUE_ACTUAL" \
            "$ISSUE_STATUS" \
            "$ISSUE_ALTS")

        # Store choice
        store_user_choice "$ISSUE_PKG" "$choice"

    done <<< "$issues"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ User choices collected"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    return 0
}

# Handle verification issues in non-interactive mode
# Auto-skips all problematic packages
handle_verification_issues_non_interactive() {
    # Check if there are issues to handle
    if ! has_verification_issues; then
        return 0
    fi

    echo ""
    echo "⚠️  Non-interactive mode: skipping problematic packages"
    echo ""

    # Format and display issues
    format_verification_issues

    # Clear previous choices
    clear_user_choices

    # Auto-skip all packages with issues
    local issues
    issues=$(get_verification_issues)

    while IFS= read -r issue; do
        [[ -z "$issue" ]] && continue

        # Parse issue
        parse_verification_issue "$issue"

        # Auto-skip
        # shellcheck disable=SC2154
        store_user_choice "$ISSUE_PKG" "SKIP"

        echo "  → Skipping: ${ISSUE_PKG}"
    done <<< "$issues"

    echo ""

    return 0
}

# Main entry point: handle verification issues
# Switches between interactive and non-interactive mode
handle_verification_issues() {
    if ! has_verification_issues; then
        return 0
    fi

    if is_interactive; then
        handle_verification_issues_interactive
    else
        handle_verification_issues_non_interactive
    fi
}

# Check if a package should be skipped based on user choice
should_skip_package() {
    local pkg="$1"

    local choice
    if choice=$(get_user_choice "$pkg"); then
        [[ "$choice" == "SKIP" ]]
    else
        # No choice recorded - don't skip
        return 1
    fi
}

# Get alternative package name if user chose one
get_alternative_package() {
    local pkg="$1"

    local choice
    if choice=$(get_user_choice "$pkg"); then
        if [[ "$choice" != "SKIP" ]]; then
            echo "$choice"
            return 0
        fi
    fi

    return 1
}

# Summary of user choices
print_user_choices_summary() {
    local skipped=0
    local replaced=0

    echo ""
    echo "📊 User Choices Summary:"
    echo ""

    if [[ "$BASH_VERSION_MAJOR" -lt 4 ]]; then
        # Bash 3.x
        for entry in "${USER_PACKAGE_CHOICES_ARRAY[@]}"; do
            local pkg="${entry%%=*}"
            local choice="${entry#*=}"

            if [[ "$choice" == "SKIP" ]]; then
                echo "  ⏭  Skipped: ${pkg}"
                ((skipped++))
            else
                echo "  🔄 Replaced: ${pkg} → ${choice}"
                ((replaced++))
            fi
        done
    else
        # Bash 4+
        for pkg in "${!USER_PACKAGE_CHOICES[@]}"; do
            local choice="${USER_PACKAGE_CHOICES[$pkg]}"

            if [[ "$choice" == "SKIP" ]]; then
                echo "  ⏭  Skipped: ${pkg}"
                ((skipped++))
            else
                echo "  🔄 Replaced: ${pkg} → ${choice}"
                ((replaced++))
            fi
        done
    fi

    echo ""
    echo "  Total skipped: ${skipped}"
    echo "  Total replaced: ${replaced}"
    echo ""
}

# Export functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f set_interactive_mode
    export -f is_interactive
    export -f store_user_choice
    export -f get_user_choice
    export -f clear_user_choices
    export -f prompt_single_package
    export -f handle_verification_issues_interactive
    export -f handle_verification_issues_non_interactive
    export -f handle_verification_issues
    export -f should_skip_package
    export -f get_alternative_package
    export -f print_user_choices_summary
fi
