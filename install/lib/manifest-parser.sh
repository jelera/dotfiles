#!/usr/bin/env bash
# YAML manifest parser using yq
# Provides functions to parse and query package manifests

# Ensure yq is available
if ! command -v yq &>/dev/null; then
    echo "Error: yq is required for manifest parsing but not found" >&2
    echo "" >&2
    echo "This should have been bootstrapped by install.sh" >&2
    echo "If you're running this script directly, install yq first:" >&2
    echo "  - Via mise:     mise install yq@latest" >&2
    echo "  - Via Homebrew: brew install yq" >&2
    echo "  - Via apt:      sudo add-apt-repository ppa:rmescandon/yq && sudo apt install yq" >&2
    echo "" >&2
    return 1
fi

# Get the directory of this script
PARSER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="${PARSER_DIR}/../schemas/package-manifest.schema.json"

# Parse entire manifest to JSON (for processing)
parse_manifest() {
    local manifest_file="$1"

    if [[ ! -f "$manifest_file" ]]; then
        echo "Error: Manifest file not found: $manifest_file" >&2
        return 1
    fi

    yq eval -o=json "$manifest_file" 2>/dev/null
    return $?
}

# Validate manifest schema
validate_manifest() {
    local manifest_file="$1"

    # Check file exists
    if [[ ! -f "$manifest_file" ]]; then
        echo "Error: Manifest file not found: $manifest_file" >&2
        return 1
    fi

    # Check valid YAML
    if ! yq eval '.' "$manifest_file" >/dev/null 2>&1; then
        echo "Error: Invalid YAML in manifest: $manifest_file" >&2
        return 1
    fi

    # Check required fields
    local version
    version=$(yq eval '.version' "$manifest_file" 2>/dev/null)
    if [[ "$version" = "null" || -z "$version" ]]; then
        echo "Error: Manifest missing version field" >&2
        return 1
    fi

    echo "Manifest validation passed" >&2
    return 0
}

# Validate manifest against JSON Schema (strict validation)
# Requires: check-jsonschema (install with: mise install pipx:check-jsonschema@latest)
validate_manifest_schema() {
    local manifest_file="$1"

    # Check file exists
    if [[ ! -f "$manifest_file" ]]; then
        echo "Error: Manifest file not found: $manifest_file" >&2
        return 1
    fi

    # Check if check-jsonschema is available
    local validator_cmd
    if command -v check-jsonschema &>/dev/null; then
        validator_cmd="check-jsonschema"
    elif command -v mise &>/dev/null && mise which check-jsonschema &>/dev/null; then
        validator_cmd="$(mise which check-jsonschema)"
    else
        echo "Warning: check-jsonschema not found, skipping schema validation" >&2
        echo "Install with: mise install pipx:check-jsonschema@latest" >&2
        # Fall back to basic validation
        validate_manifest "$manifest_file"
        return $?
    fi

    # Check if schema file exists
    if [[ ! -f "$SCHEMA_FILE" ]]; then
        echo "Error: Schema file not found: $SCHEMA_FILE" >&2
        return 1
    fi

    # Run schema validation
    if "$validator_cmd" --schemafile "$SCHEMA_FILE" "$manifest_file" >/dev/null 2>&1; then
        echo "Schema validation passed" >&2
        return 0
    else
        echo "Error: Schema validation failed" >&2
        "$validator_cmd" --schemafile "$SCHEMA_FILE" "$manifest_file" >&2
        return 1
    fi
}

# Get packages filtered by category
get_packages_by_category() {
    local manifest_file="$1"
    local category="$2"

    if [[ ! -f "$manifest_file" ]]; then
        return 1
    fi

    yq eval ".packages | to_entries | .[] | select(.value.category == \"$category\") | .key" "$manifest_file" 2>/dev/null
}

# Get priority chain for a specific package
get_package_priority() {
    local manifest_file="$1"
    local package="$2"

    if [[ ! -f "$manifest_file" ]]; then
        return 1
    fi

    # Try package-specific priority first
    local pkg_priority
    pkg_priority=$(yq eval ".packages.\"${package}\".priority[]?" "$manifest_file" 2>/dev/null)

    if [[ -n "$pkg_priority" && "$pkg_priority" != "null" ]]; then
        echo "$pkg_priority"
        return 0
    fi

    # Fall back to category priority
    local category
    category=$(yq eval ".packages.\"${package}\".category" "$manifest_file" 2>/dev/null)

    if [[ -z "$category" || "$category" = "null" ]]; then
        return 1
    fi

    yq eval ".categories.\"${category}\".priority[]?" "$manifest_file" 2>/dev/null
}

# Filter packages by platform (ubuntu, macos)
get_packages_for_platform() {
    local manifest_file="$1"
    local platform="$2"

    if [[ ! -f "$manifest_file" ]]; then
        return 1
    fi

    # Get all packages and filter by platform
    local all_packages
    all_packages=$(yq eval '.packages | keys | .[]' "$manifest_file" 2>/dev/null)

    for pkg in $all_packages; do
        local pkg_platforms
        pkg_platforms=$(yq eval ".packages.\"${pkg}\".platforms[]?" "$manifest_file" 2>/dev/null)

        # Include if no platform restriction or if platform matches
        if [[ -z "$pkg_platforms" || "$pkg_platforms" = "null" ]]; then
            echo "$pkg"
        elif echo "$pkg_platforms" | grep -q "^${platform}$"; then
            echo "$pkg"
        fi
    done
}

# Filter packages by profile
get_packages_for_profile() {
    local manifest_file="$1"
    local profile="$2"

    if [[ ! -f "$manifest_file" ]]; then
        return 1
    fi

    # Check if profile exists
    local profile_exists
    profile_exists=$(yq eval ".profiles | has(\"${profile}\")" "$manifest_file" 2>/dev/null)

    if [[ "$profile_exists" != "true" ]]; then
        echo "Error: Profile '${profile}' not found in manifest" >&2
        return 1
    fi

    # Check if profile has explicit packages list
    local explicit_packages
    explicit_packages=$(yq eval ".profiles.\"${profile}\".packages[]?" "$manifest_file" 2>/dev/null)

    if [[ -n "$explicit_packages" && "$explicit_packages" != "null" ]]; then
        echo "$explicit_packages"
        return 0
    fi

    # Otherwise, use includes/excludes
    local includes
    includes=$(yq eval ".profiles.\"${profile}\".includes[]?" "$manifest_file" 2>/dev/null)

    local excludes
    excludes=$(yq eval ".profiles.\"${profile}\".excludes[]?" "$manifest_file" 2>/dev/null)

    if [[ -z "$includes" || "$includes" = "null" ]]; then
        # No includes, return all packages not in excludes
        if [[ -n "$excludes" && "$excludes" != "null" ]]; then
            yq eval ".packages | to_entries | .[] |
                select(.value.category as \$cat | \"$excludes\" | contains(\$cat) | not) |
                .key" "$manifest_file" 2>/dev/null
        else
            yq eval ".packages | keys | .[]" "$manifest_file" 2>/dev/null
        fi
        return 0
    fi

    # Return packages from included categories, excluding excluded categories
    {
        for category in $includes; do
            get_packages_by_category "$manifest_file" "$category"
        done
    } | if [[ -n "$excludes" && "$excludes" != "null" ]]; then
        # Filter out excluded categories
        grep -v -F -f <(
            for exclude_cat in $excludes; do
                get_packages_by_category "$manifest_file" "$exclude_cat"
            done
        ) 2>/dev/null || cat
    else
        cat
    fi
}

# Check if package is managed by mise (in mise/config.toml)
is_managed_by_mise() {
    local manifest_file="$1"
    local package="$2"

    if [[ ! -f "$manifest_file" ]]; then
        return 1
    fi

    local managed_by
    managed_by=$(yq eval ".packages.\"${package}\".managed_by" "$manifest_file" 2>/dev/null)

    [[ "$managed_by" = "mise" ]]
}

# Get package manager specific options
get_package_manager_config() {
    local manifest_file="$1"
    local package="$2"
    local manager="$3"  # apt, homebrew, mise, etc.

    if [[ ! -f "$manifest_file" ]]; then
        return 1
    fi

    yq eval ".packages.\"${package}\".${manager}" "$manifest_file" 2>/dev/null
}


# ============================================================================
# Multi-Manifest Loading Functions (NEW)
# ============================================================================

# Load manifest files for a platform
# Returns space-separated list of manifest file paths
load_manifests_for_platform() {
    local manifest_dir="$1"
    local platform="$2"

    local manifests=()

    # Always load common.yaml first
    local common_manifest="${manifest_dir}/common.yaml"
    if [[ -f "$common_manifest" ]]; then
        manifests+=("$common_manifest")
    fi

    # Load platform-specific manifest
    local platform_manifest="${manifest_dir}/${platform}.yaml"
    if [[ -f "$platform_manifest" ]]; then
        manifests+=("$platform_manifest")
    fi

    echo "${manifests[@]}"
}

# Merge multiple manifest files into unified view
# Later manifests override earlier ones
merge_manifests() {
    local manifests=("$@")

    if [[ ${#manifests[@]} -eq 0 ]]; then
        echo "Error: No manifests to merge" >&2
        return 1
    fi

    # Single manifest - just cat it
    if [[ ${#manifests[@]} -eq 1 ]]; then
        cat "${manifests[0]}"
        return 0
    fi

    # Use yq to merge YAML files
    # The '*' operator merges objects, with later values overriding earlier ones
    # shellcheck disable=SC2016
    yq eval-all '. as $item ireduce ({}; . * $item)' "${manifests[@]}" 2>/dev/null
}

# ============================================================================
# Mise Tools Expansion Functions (NEW)
# ============================================================================

# Get all mise tools for a category
get_mise_tools_by_category() {
    local manifest_file="$1"
    local category="$2"

    if [[ ! -f "$manifest_file" ]]; then
        return 1
    fi

    yq eval ".mise_tools.categories.\"${category}\".tools[].name" "$manifest_file" 2>/dev/null
}

# Check if package is in mise_tools section
is_in_mise_tools() {
    local manifest_file="$1"
    local package="$2"

    if [[ ! -f "$manifest_file" ]]; then
        return 1
    fi

    # Check all mise_tools categories
    local categories
    categories=$(yq eval '.mise_tools.categories | keys | .[]' "$manifest_file" 2>/dev/null)

    for cat in $categories; do
        local tools
        tools=$(yq eval ".mise_tools.categories.\"${cat}\".tools[].name" "$manifest_file" 2>/dev/null)

        if echo "$tools" | grep -q "^${package}$"; then
            return 0
        fi
    done

    return 1
}

# Get mise tool description
get_mise_tool_description() {
    local manifest_file="$1"
    local package="$2"

    if [[ ! -f "$manifest_file" ]]; then
        return 1
    fi

    # Search all categories for the tool
    local categories
    categories=$(yq eval '.mise_tools.categories | keys | .[]' "$manifest_file" 2>/dev/null)

    for cat in $categories; do
        local desc
        desc=$(yq eval ".mise_tools.categories.\"${cat}\".tools[] | select(.name == \"${package}\") | .desc" "$manifest_file" 2>/dev/null)

        if [[ -n "$desc" && "$desc" != "null" ]]; then
            echo "$desc"
            return 0
        fi
    done

    return 1
}

# Expand mise_tools section into package format
expand_mise_tools() {
    local manifest_file="$1"

    if [[ ! -f "$manifest_file" ]]; then
        return 1
    fi

    # Check if mise_tools.global is set
    local global
    global=$(yq eval '.mise_tools.global' "$manifest_file" 2>/dev/null)
    if [[ "$global" = "null" ]]; then
        global="true"  # Default to true
    fi

    # Get all categories
    local categories
    categories=$(yq eval '.mise_tools.categories | keys | .[]' "$manifest_file" 2>/dev/null)

    if [[ -z "$categories" || "$categories" = "null" ]]; then
        return 0  # No mise_tools section, return successfully with no output
    fi

    # Process each category
    for cat in $categories; do
        # Get all tools in this category
        local tool_count
        tool_count=$(yq eval ".mise_tools.categories.\"${cat}\".tools | length" "$manifest_file" 2>/dev/null)

        for ((i=0; i<tool_count; i++)); do
            local name desc version
            name=$(yq eval ".mise_tools.categories.\"${cat}\".tools[$i].name" "$manifest_file" 2>/dev/null)
            desc=$(yq eval ".mise_tools.categories.\"${cat}\".tools[$i].desc" "$manifest_file" 2>/dev/null)
            version=$(yq eval ".mise_tools.categories.\"${cat}\".tools[$i].version" "$manifest_file" 2>/dev/null)

            if [[ "$version" = "null" ]]; then
                version="latest"
            fi

            # Generate expanded package entry
            cat <<EOF
  $name:
    category: $cat
    description: "$desc"
    managed_by: mise
    global_install: $global
EOF
        done
    done
}

# Get all packages (merged from packages and mise_tools sections)
get_all_packages_merged() {
    local manifest_file="$1"

    if [[ ! -f "$manifest_file" ]]; then
        return 1
    fi

    {
        # Get packages from packages section
        yq eval '.packages | keys | .[]' "$manifest_file" 2>/dev/null

        # Get packages from mise_tools section
        local categories
        categories=$(yq eval '.mise_tools.categories | keys | .[]' "$manifest_file" 2>/dev/null)

        for cat in $categories; do
            yq eval ".mise_tools.categories.\"${cat}\".tools[].name" "$manifest_file" 2>/dev/null
        done
    } | sort -u
}

# Get packages for profile with multi-manifest support
get_packages_for_profile_multi() {
    local manifest_dir="$1"
    local profile="$2"
    local platform="${3:-ubuntu}"

    # Load and merge manifests
    local manifests
    # shellcheck disable=SC2207
    manifests=($(load_manifests_for_platform "$manifest_dir" "$platform"))

    if [[ ${#manifests[@]} -eq 0 ]]; then
        echo "Error: No manifests found for platform $platform" >&2
        return 1
    fi

    # Merge manifests
    local merged_manifest
    merged_manifest=$(merge_manifests "${manifests[@]}")

    # Create temp file for merged manifest
    local temp_manifest
    temp_manifest=$(mktemp)
    echo "$merged_manifest" > "$temp_manifest"

    # Get packages for profile from merged manifest
    local packages
    packages=$(get_packages_for_profile "$temp_manifest" "$profile")
    local exit_code=$?

    # Clean up
    rm -f "$temp_manifest"

    echo "$packages"
    return "$exit_code"
}
