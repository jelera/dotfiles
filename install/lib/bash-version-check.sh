#!/usr/bin/env bash
# Bash version check helper
# Ensures Bash 4+ is available for scripts requiring associative arrays

# Check if Bash version meets minimum requirement (4.0)
# Usage: require_bash4 [calling_script_name]
require_bash4() {
    local script_name="${1:-this script}"

    if [[ "${BASH_VERSINFO[0]:-3}" -lt 4 ]]; then
        echo "Error: ${script_name} requires Bash 4.0 or newer" >&2
        echo "Current version: ${BASH_VERSION}" >&2
        echo "" >&2
        echo "On macOS, Bash 4+ will be installed automatically during setup." >&2
        echo "If you're running this in dry-run mode, install bash first:" >&2
        echo "  brew install bash" >&2
        echo "Then re-run with the newer bash:" >&2
        echo "  /opt/homebrew/bin/bash ./install.sh --dry-run  # Apple Silicon" >&2
        echo "  /usr/local/bin/bash ./install.sh --dry-run     # Intel Mac" >&2
        return 1
    fi

    return 0
}

# Export the function if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f require_bash4 2>/dev/null || true
fi
