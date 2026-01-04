#!/usr/bin/env bash
# YAML manifest parser using yq
# Provides functions to parse and query package manifests

# Ensure yq is available
if ! command -v yq &>/dev/null; then
    echo "Error: yq is required but not installed" >&2
    echo "Install with: mise install yq@latest" >&2
    return 1
fi

# Get the directory of this script
PARSER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="${PARSER_DIR}/../schemas/package-manifest.schema.json"

# Parse entire manifest to JSON (for processing)
parse_manifest() {
    local manifest_file="$1"

    if [ ! -f "$manifest_file" ]; then
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
    if [ ! -f "$manifest_file" ]; then
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
    if [ "$version" = "null" ] || [ -z "$version" ]; then
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
    if [ ! -f "$manifest_file" ]; then
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
    if [ ! -f "$SCHEMA_FILE" ]; then
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

    if [ ! -f "$manifest_file" ]; then
        return 1
    fi

    yq eval ".packages | to_entries | .[] | select(.value.category == \"$category\") | .key" "$manifest_file" 2>/dev/null
}

# Get priority chain for a specific package
get_package_priority() {
    local manifest_file="$1"
    local package="$2"

    if [ ! -f "$manifest_file" ]; then
        return 1
    fi

    # Try package-specific priority first
    local pkg_priority
    pkg_priority=$(yq eval ".packages.\"${package}\".priority[]?" "$manifest_file" 2>/dev/null)

    if [ -n "$pkg_priority" ] && [ "$pkg_priority" != "null" ]; then
        echo "$pkg_priority"
        return 0
    fi

    # Fall back to category priority
    local category
    category=$(yq eval ".packages.\"${package}\".category" "$manifest_file" 2>/dev/null)

    if [ -z "$category" ] || [ "$category" = "null" ]; then
        return 1
    fi

    yq eval ".categories.\"${category}\".priority[]?" "$manifest_file" 2>/dev/null
}

# Filter packages by platform (ubuntu, macos)
get_packages_for_platform() {
    local manifest_file="$1"
    local platform="$2"

    if [ ! -f "$manifest_file" ]; then
        return 1
    fi

    # Get all packages and filter by platform
    local all_packages
    all_packages=$(yq eval '.packages | keys | .[]' "$manifest_file" 2>/dev/null)

    for pkg in $all_packages; do
        local pkg_platforms
        pkg_platforms=$(yq eval ".packages.\"${pkg}\".platforms[]?" "$manifest_file" 2>/dev/null)

        # Include if no platform restriction or if platform matches
        if [ -z "$pkg_platforms" ] || [ "$pkg_platforms" = "null" ]; then
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

    if [ ! -f "$manifest_file" ]; then
        return 1
    fi

    # Check if profile has explicit packages list
    local explicit_packages
    explicit_packages=$(yq eval ".profiles.\"${profile}\".packages[]?" "$manifest_file" 2>/dev/null)

    if [ -n "$explicit_packages" ] && [ "$explicit_packages" != "null" ]; then
        echo "$explicit_packages"
        return 0
    fi

    # Otherwise, use includes/excludes
    local includes
    includes=$(yq eval ".profiles.\"${profile}\".includes[]?" "$manifest_file" 2>/dev/null)

    local excludes
    excludes=$(yq eval ".profiles.\"${profile}\".excludes[]?" "$manifest_file" 2>/dev/null)

    if [ -z "$includes" ] || [ "$includes" = "null" ]; then
        # No includes, return all packages not in excludes
        if [ -n "$excludes" ] && [ "$excludes" != "null" ]; then
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
    } | if [ -n "$excludes" ] && [ "$excludes" != "null" ]; then
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

    if [ ! -f "$manifest_file" ]; then
        return 1
    fi

    local managed_by
    managed_by=$(yq eval ".packages.\"${package}\".managed_by" "$manifest_file" 2>/dev/null)

    [ "$managed_by" = "mise" ]
}

# Get package manager specific options
get_package_manager_config() {
    local manifest_file="$1"
    local package="$2"
    local manager="$3"  # apt, homebrew, mise, etc.

    if [ ! -f "$manifest_file" ]; then
        return 1
    fi

    yq eval ".packages.\"${package}\".${manager}" "$manifest_file" 2>/dev/null
}

# Get packages in bulk install group
get_bulk_group_packages() {
    local manifest_file="$1"
    local group_name="$2"

    if [ ! -f "$manifest_file" ]; then
        return 1
    fi

    yq eval ".bulk_install_groups.\"${group_name}\".packages[]?" "$manifest_file" 2>/dev/null
}

# Check if bulk install group is enabled
is_bulk_group_enabled() {
    local manifest_file="$1"
    local group_name="$2"

    if [ ! -f "$manifest_file" ]; then
        return 1
    fi

    local enabled
    enabled=$(yq eval ".bulk_install_groups.\"${group_name}\".enabled" "$manifest_file" 2>/dev/null)

    [ "$enabled" = "true" ]
}

# Get all categories defined in manifest
get_all_categories() {
    local manifest_file="$1"

    if [ ! -f "$manifest_file" ]; then
        return 1
    fi

    yq eval ".categories | keys | .[]" "$manifest_file" 2>/dev/null
}

# Get all profiles defined in manifest
get_all_profiles() {
    local manifest_file="$1"

    if [ ! -f "$manifest_file" ]; then
        return 1
    fi

    yq eval ".profiles | keys | .[]" "$manifest_file" 2>/dev/null
}
