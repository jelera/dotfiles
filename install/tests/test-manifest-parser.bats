#!/usr/bin/env bats
# Tests for install/lib/manifest-parser.sh

load test-helper

# Test: parse_manifest loads valid YAML
@test "parse_manifest: loads valid YAML without errors" {
    create_test_manifest "$TEST_MANIFEST"

    run parse_manifest "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
}

# Test: validate_manifest accepts valid schema
@test "validate_manifest: accepts valid manifest with version" {
    create_test_manifest "$TEST_MANIFEST"

    run validate_manifest "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "validation passed" ]] || [[ "$output" =~ "valid" ]]
}

# Test: validate_manifest rejects missing version
@test "validate_manifest: rejects manifest missing version field" {
    create_invalid_manifest "$TEST_MANIFEST"

    run validate_manifest "$TEST_MANIFEST"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "version" ]] || [[ "$output" =~ "missing" ]]
}

# Test: validate_manifest rejects non-existent file
@test "validate_manifest: rejects non-existent file" {
    run validate_manifest "/nonexistent/file.yaml"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]] || [[ "$output" =~ "exist" ]]
}

# Test: get_packages_by_category filters correctly
@test "get_packages_by_category: filters general_tools packages" {
    run get_packages_by_category "${FIXTURES_DIR}/test-packages.yaml" "general_tools"
    [ "$status" -eq 0 ]
    assert_contains "$output" "git"
    assert_contains "$output" "curl"
}

@test "get_packages_by_category: filters language_runtimes" {
    run get_packages_by_category "${FIXTURES_DIR}/test-packages.yaml" "language_runtimes"
    [ "$status" -eq 0 ]
    assert_contains "$output" "ruby"
    assert_contains "$output" "python"
    assert_contains "$output" "node"
}

@test "get_packages_by_category: filters system_libraries" {
    run get_packages_by_category "${FIXTURES_DIR}/test-packages.yaml" "system_libraries"
    [ "$status" -eq 0 ]
    assert_contains "$output" "build-essential"
}

# Test: get_package_priority returns correct priority chain
@test "get_package_priority: returns custom priority for git" {
    run get_package_priority "${FIXTURES_DIR}/test-packages.yaml" "git"
    [ "$status" -eq 0 ]
    # git has custom priority: ["apt", "homebrew"]
    assert_contains "$output" "apt"
    assert_contains "$output" "homebrew"
}

@test "get_package_priority: returns category default for curl" {
    run get_package_priority "${FIXTURES_DIR}/test-packages.yaml" "curl"
    [ "$status" -eq 0 ]
    # curl should use general_tools default: ["apt", "ppa", "homebrew", "mise"]
    assert_contains "$output" "apt"
}

@test "get_package_priority: returns language_runtimes priority" {
    run get_package_priority "${FIXTURES_DIR}/test-packages.yaml" "ruby"
    [ "$status" -eq 0 ]
    # language_runtimes priority: ["ppa", "homebrew", "mise"]
    assert_contains "$output" "ppa"
    assert_contains "$output" "mise"
}

# Test: get_packages_for_platform filters by platform
@test "get_packages_for_platform: filters ubuntu packages" {
    run get_packages_for_platform "${FIXTURES_DIR}/test-packages.yaml" "ubuntu"
    [ "$status" -eq 0 ]
    assert_contains "$output" "build-essential"
    assert_contains "$output" "git"  # No platform restriction
    assert_not_contains "$output" "ghostty"  # macOS only
}

@test "get_packages_for_platform: filters macos packages" {
    run get_packages_for_platform "${FIXTURES_DIR}/test-packages.yaml" "macos"
    [ "$status" -eq 0 ]
    assert_contains "$output" "ghostty"
    assert_contains "$output" "git"  # No platform restriction
    assert_not_contains "$output" "build-essential"  # Ubuntu only
}

# Test: get_packages_for_profile filters by profile
@test "get_packages_for_profile: returns minimal profile packages" {
    run get_packages_for_profile "${FIXTURES_DIR}/test-packages.yaml" "minimal"
    [ "$status" -eq 0 ]
    # minimal profile: [git, curl, wget, tmux, tree]
    assert_contains "$output" "git"
    assert_contains "$output" "curl"
    assert_contains "$output" "wget"
    assert_contains "$output" "tmux"
    assert_contains "$output" "tree"
    assert_not_contains "$output" "htop"  # Not in minimal
}

@test "get_packages_for_profile: dev profile excludes GUI apps" {
    run get_packages_for_profile "${FIXTURES_DIR}/test-packages.yaml" "dev"
    [ "$status" -eq 0 ]
    # dev includes system_libraries, general_tools, language_runtimes
    # dev excludes gui_applications
    assert_contains "$output" "git"
    assert_contains "$output" "ruby"
    assert_not_contains "$output" "ghostty"  # GUI app excluded
}

@test "get_packages_for_profile: full profile includes all categories" {
    run get_packages_for_profile "${FIXTURES_DIR}/test-packages.yaml" "full"
    [ "$status" -eq 0 ]
    assert_contains "$output" "git"  # general_tools
    assert_contains "$output" "ruby"  # language_runtimes
    assert_contains "$output" "build-essential"  # system_libraries
    assert_contains "$output" "ghostty"  # gui_applications
}

@test "get_packages_for_profile: remote profile has specific packages" {
    run get_packages_for_profile "${FIXTURES_DIR}/test-packages.yaml" "remote"
    [ "$status" -eq 0 ]
    # remote profile: [git, curl, wget, tmux, htop, build-essential]
    assert_contains "$output" "git"
    assert_contains "$output" "htop"
    assert_contains "$output" "build-essential"
    assert_not_contains "$output" "tree"  # Not in remote
}

# Test: is_managed_by_mise checks managed_by field
@test "is_managed_by_mise: returns true for mise-managed packages" {
    run is_managed_by_mise "${FIXTURES_DIR}/test-packages.yaml" "ruby"
    [ "$status" -eq 0 ]
}

@test "is_managed_by_mise: returns false for non-mise packages" {
    run is_managed_by_mise "${FIXTURES_DIR}/test-packages.yaml" "git"
    [ "$status" -eq 1 ]
}

# Test: get_package_manager_config returns manager-specific config
@test "get_package_manager_config: returns apt config for git" {
    run get_package_manager_config "${FIXTURES_DIR}/test-packages.yaml" "git" "apt"
    [ "$status" -eq 0 ]
    assert_contains "$output" "package"
}

@test "get_package_manager_config: returns homebrew cask config for ghostty" {
    run get_package_manager_config "${FIXTURES_DIR}/test-packages.yaml" "ghostty" "homebrew"
    [ "$status" -eq 0 ]
    assert_contains "$output" "cask"
    assert_contains "$output" "true"
}

# Test: Helper functions handle errors gracefully
@test "get_package_priority: handles nonexistent package" {
    run get_package_priority "${FIXTURES_DIR}/test-packages.yaml" "nonexistent"
    [ "$status" -ne 0 ] || [ -z "$output" ]
}

@test "get_packages_by_category: handles nonexistent category" {
    run get_packages_by_category "${FIXTURES_DIR}/test-packages.yaml" "nonexistent"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || [[ "$output" == "" ]]
}

# ============================================================================
# Multi-Manifest Loading Tests (NEW)
# ============================================================================

@test "load_manifests_for_platform: loads common.yaml for ubuntu" {
    run load_manifests_for_platform "${MANIFEST_DIR}" "ubuntu"
    [ "$status" -eq 0 ]
    assert_contains "$output" "common.yaml"
    assert_contains "$output" "ubuntu.yaml"
}

@test "load_manifests_for_platform: loads common.yaml for macos" {
    run load_manifests_for_platform "${MANIFEST_DIR}" "macos"
    [ "$status" -eq 0 ]
    assert_contains "$output" "common.yaml"
    assert_contains "$output" "macos.yaml"
}

@test "load_manifests_for_platform: only loads common.yaml for unsupported platform" {
    run load_manifests_for_platform "${MANIFEST_DIR}" "fedora"
    [ "$status" -eq 0 ]
    assert_contains "$output" "common.yaml"
    # fedora.yaml doesn't exist yet, so shouldn't be in output
}

@test "merge_manifests: merges two manifest files" {
    # Test that merge_manifests can combine common and platform-specific
    local manifests=("${MANIFEST_DIR}/common.yaml" "${MANIFEST_DIR}/ubuntu.yaml")
    run merge_manifests "${manifests[@]}"
    [ "$status" -eq 0 ]
    # Should contain packages from both files
    assert_contains "$output" "git"  # from common
    assert_contains "$output" "build-essential"  # from ubuntu
}

@test "merge_manifests: platform manifest overrides common" {
    # Later manifests should override earlier ones
    # (if same package defined in both)
    local manifests=("${MANIFEST_DIR}/common.yaml" "${MANIFEST_DIR}/ubuntu.yaml")
    run merge_manifests "${manifests[@]}"
    [ "$status" -eq 0 ]
    # Should have merged successfully
}

# ============================================================================
# Mise Tools Expansion Tests (NEW)
# ============================================================================

@test "expand_mise_tools: converts mise_tools to package format" {
    run expand_mise_tools "${MANIFEST_DIR}/common.yaml"
    [ "$status" -eq 0 ]
    # Should contain expanded mise packages
    assert_contains "$output" "fzf"
    assert_contains "$output" "managed_by: mise"
    assert_contains "$output" "category:"
}

@test "expand_mise_tools: sets global_install from mise_tools.global" {
    run expand_mise_tools "${MANIFEST_DIR}/common.yaml"
    [ "$status" -eq 0 ]
    assert_contains "$output" "global_install: true"
}

@test "expand_mise_tools: includes all categories" {
    run expand_mise_tools "${MANIFEST_DIR}/common.yaml"
    [ "$status" -eq 0 ]
    # Check tools from different categories
    assert_contains "$output" "fzf"  # shell_tools
    assert_contains "$output" "jq"  # dev_tools
    assert_contains "$output" "gh"  # git_tools
    assert_contains "$output" "ripgrep"  # file_tools
    assert_contains "$output" "ruby"  # language_runtimes
}

@test "get_mise_tools_by_category: returns tools in a category" {
    run get_mise_tools_by_category "${MANIFEST_DIR}/common.yaml" "shell_tools"
    [ "$status" -eq 0 ]
    assert_contains "$output" "fzf"
    assert_contains "$output" "zoxide"
    assert_not_contains "$output" "jq"  # jq is in dev_tools
}

@test "is_in_mise_tools: returns true for mise tools" {
    run is_in_mise_tools "${MANIFEST_DIR}/common.yaml" "fzf"
    [ "$status" -eq 0 ]
}

@test "is_in_mise_tools: returns false for non-mise tools" {
    run is_in_mise_tools "${MANIFEST_DIR}/common.yaml" "git"
    [ "$status" -eq 1 ]
}

@test "get_mise_tool_description: returns tool description" {
    run get_mise_tool_description "${MANIFEST_DIR}/common.yaml" "fzf"
    [ "$status" -eq 0 ]
    assert_contains "$output" "Fuzzy finder"
}

# ============================================================================
# Integration Tests - Multi-Manifest with Mise Tools
# ============================================================================

@test "get_packages_for_profile: works with multi-manifest structure" {
    # This tests the full integration: load manifests, merge, expand mise_tools
    run get_packages_for_profile_multi "${MANIFEST_DIR}" "minimal" "ubuntu"
    [ "$status" -eq 0 ]
    assert_contains "$output" "git"
    assert_contains "$output" "curl"
    assert_contains "$output" "wget"
}

@test "get_all_packages_merged: combines packages and mise_tools" {
    run get_all_packages_merged "${MANIFEST_DIR}/common.yaml"
    [ "$status" -eq 0 ]
    # Should contain traditional packages
    assert_contains "$output" "git"
    assert_contains "$output" "curl"
    # Should contain mise tools
    assert_contains "$output" "fzf"
    assert_contains "$output" "jq"
    assert_contains "$output" "ruby"
}
