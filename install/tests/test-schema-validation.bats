#!/usr/bin/env bats
# Tests for JSON Schema validation of package manifests

load test-helper

# Test: Valid manifests pass schema validation
@test "schema validation: accepts valid test fixture" {
    run validate_manifest_schema "${FIXTURES_DIR}/test-packages.yaml"
    [ "$status" -eq 0 ]
    assert_contains "$output" "validation passed"
}

@test "schema validation: accepts actual production manifests" {
    # Test common.yaml
    run validate_manifest_schema "${MANIFEST_DIR}/common.yaml"
    [ "$status" -eq 0 ]
    assert_contains "$output" "validation passed"

    # Test ubuntu.yaml
    run validate_manifest_schema "${MANIFEST_DIR}/ubuntu.yaml"
    [ "$status" -eq 0 ]
    assert_contains "$output" "validation passed"

    # Test macos.yaml
    run validate_manifest_schema "${MANIFEST_DIR}/macos.yaml"
    [ "$status" -eq 0 ]
    assert_contains "$output" "validation passed"
}

# Test: Missing required top-level fields
@test "schema validation: rejects manifest without version" {
    cat > "$TEST_MANIFEST" <<'EOF'
profiles:
  minimal:
    description: "Test"
    packages: [git]
categories:
  general_tools:
    description: "Tools"
    priority: ["apt"]
packages:
  git:
    category: general_tools
    description: "VCS"
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -ne 0 ]
}

@test "schema validation: accepts platform manifest without profiles" {
    # Platform-specific manifests (ubuntu.yaml, macos.yaml) can have just packages
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
categories:
  general_tools:
    description: "Tools"
    priority: ["apt"]
packages:
  git:
    category: general_tools
    description: "VCS"
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
}

@test "schema validation: accepts platform manifest without categories" {
    # Platform-specific manifests can omit categories if using common ones
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [git]
packages:
  git:
    category: general_tools
    description: "VCS"
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
}

@test "schema validation: accepts manifest without packages" {
    # Manifests can have just profiles/categories (will be merged with platform-specific)
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [git]
categories:
  general_tools:
    description: "Tools"
    priority: ["apt"]
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
}

# Test: Version field accepts both string and number
@test "schema validation: accepts version as string" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: "1.0"
profiles:
  minimal:
    description: "Test"
    packages: [git]
categories:
  general_tools:
    description: "Tools"
    priority: ["apt"]
packages:
  git:
    category: general_tools
    description: "VCS"
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
}

@test "schema validation: accepts version as number" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [git]
categories:
  general_tools:
    description: "Tools"
    priority: ["apt"]
packages:
  git:
    category: general_tools
    description: "VCS"
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
}

# Test: Profile validation
@test "schema validation: rejects profile with both packages and includes" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  conflict:
    description: "Test"
    packages: [git]
    includes: [general_tools]
categories:
  general_tools:
    description: "Tools"
    priority: ["apt"]
packages:
  git:
    category: general_tools
    description: "VCS"
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -ne 0 ]
}

@test "schema validation: rejects profile without description" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    packages: [git]
categories:
  general_tools:
    description: "Tools"
    priority: ["apt"]
packages:
  git:
    category: general_tools
    description: "VCS"
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -ne 0 ]
}

@test "schema validation: accepts profile with includes only" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  dev:
    description: "Development profile"
    includes: [general_tools]
categories:
  general_tools:
    description: "Tools"
    priority: ["apt"]
packages:
  git:
    category: general_tools
    description: "VCS"
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
}

@test "schema validation: accepts profile with excludes only" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  headless:
    description: "Headless profile"
    excludes: [gui_applications]
categories:
  general_tools:
    description: "Tools"
    priority: ["apt"]
  gui_applications:
    description: "GUI apps"
    priority: ["homebrew-cask"]
packages:
  git:
    category: general_tools
    description: "VCS"
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
}

# Test: Category validation
@test "schema validation: rejects category without description" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [git]
categories:
  general_tools:
    priority: ["apt"]
packages:
  git:
    category: general_tools
    description: "VCS"
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -ne 0 ]
}

@test "schema validation: rejects category without priority" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [git]
categories:
  general_tools:
    description: "Tools"
packages:
  git:
    category: general_tools
    description: "VCS"
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -ne 0 ]
}

@test "schema validation: rejects invalid priority manager" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [git]
categories:
  general_tools:
    description: "Tools"
    priority: ["snap"]
packages:
  git:
    category: general_tools
    description: "VCS"
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -ne 0 ]
}

@test "schema validation: accepts valid priority managers" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [git]
categories:
  general_tools:
    description: "Tools"
    priority: ["mise", "apt", "ppa", "homebrew", "homebrew-cask", "flatpak", "source"]
packages:
  git:
    category: general_tools
    description: "VCS"
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
}

# Test: Package validation
@test "schema validation: rejects package without category" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [git]
categories:
  general_tools:
    description: "Tools"
    priority: ["apt"]
packages:
  git:
    description: "VCS"
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -ne 0 ]
}

@test "schema validation: rejects package without description" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [git]
categories:
  general_tools:
    description: "Tools"
    priority: ["apt"]
packages:
  git:
    category: general_tools
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -ne 0 ]
}

@test "schema validation: accepts package with valid platforms" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [git]
categories:
  general_tools:
    description: "Tools"
    priority: ["apt"]
packages:
  git:
    category: general_tools
    description: "VCS"
    platforms: ["ubuntu", "macos", "kubuntu", "xubuntu"]
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
}

@test "schema validation: rejects invalid platform value" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [git]
categories:
  general_tools:
    description: "Tools"
    priority: ["apt"]
packages:
  git:
    category: general_tools
    description: "VCS"
    platforms: ["windows"]
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -ne 0 ]
}

# Test: Package manager configs
@test "schema validation: accepts apt config with package" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [git]
categories:
  general_tools:
    description: "Tools"
    priority: ["apt"]
packages:
  git:
    category: general_tools
    description: "VCS"
    apt:
      package: git
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
}

@test "schema validation: accepts homebrew config with cask" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [ghostty]
categories:
  gui_applications:
    description: "GUI apps"
    priority: ["homebrew-cask"]
packages:
  ghostty:
    category: gui_applications
    description: "Terminal"
    homebrew:
      package: ghostty
      cask: true
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
}

@test "schema validation: accepts PPA config with ppa: prefix" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [tool]
categories:
  general_tools:
    description: "Tools"
    priority: ["ppa"]
packages:
  tool:
    category: general_tools
    description: "Tool from PPA"
    ppa:
      repository: "ppa:user/repo"
      package: tool
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
}

@test "schema validation: rejects PPA without ppa: prefix" {
    cat > "$TEST_MANIFEST" <<'EOF'
version: 1.0
profiles:
  minimal:
    description: "Test"
    packages: [tool]
categories:
  general_tools:
    description: "Tools"
    priority: ["ppa"]
packages:
  tool:
    category: general_tools
    description: "Tool from PPA"
    ppa:
      repository: "user/repo"
      package: tool
EOF

    run validate_manifest_schema "$TEST_MANIFEST"
    [ "$status" -ne 0 ]
}

