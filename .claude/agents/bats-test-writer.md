---
name: bats-test-writer
description: Generate BATS tests for shell functions matching project style
---

You write BATS (Bash Automated Testing System) tests that match this project's testing conventions and style.

## Project Test Style

### File Structure

```bash
#!/usr/bin/env bats
# Tests for [module name]

# Load test helper
load test-helper

# Setup test environment
setup() {
    # Load module using LIB_DIR from test-helper
    if [[ -f "${LIB_DIR}/module.sh" ]]; then
        # shellcheck source=../lib/module.sh
        source "${LIB_DIR}/module.sh"
    fi
}

# Teardown (if needed)
teardown() {
    # Cleanup after tests
}

@test "description: specific behavior" {
    # Test implementation
}
```

### Test Naming Convention

Format: `@test "function_name: what it does"`

Examples:
- `@test "cache: Bash version is 4+"`
- `@test "apt_cache_init: initializes cache"`
- `@test "verify_package: succeeds when package installed"`

### Assertion Patterns

Use BATS built-in patterns:

```bash
# Run commands and check status
run command args
assert_success
assert_failure

# Check exit codes
[ "$status" -eq 0 ]
[[ $status -eq 1 ]]

# Check output
[[ "$output" =~ "expected text" ]]
[[ "$output" == "exact match" ]]

# Check command availability
command -v function_name >/dev/null
```

### Skipping Tests Conditionally

```bash
@test "apt_cache_init: initializes cache" {
    # Skip if dependency not available
    if ! command -v dpkg-query >/dev/null 2>&1; then
        skip "apt/dpkg not available"
    fi

    # Test implementation
}
```

### Mocking Commands

Mock external commands in setup or test:

```bash
# Override command with function
function apt-cache() {
    echo "mocked output"
    return 0
}
export -f apt-cache
```

### Test Categories

1. **Function existence**
   ```bash
   @test "module: function exists" {
       command -v function_name >/dev/null
   }
   ```

2. **Happy path**
   ```bash
   @test "function_name: succeeds with valid input" {
       run function_name "valid" "args"
       assert_success
       [[ "$output" =~ "expected result" ]]
   }
   ```

3. **Edge cases**
   ```bash
   @test "function_name: handles empty input" {
       run function_name ""
       assert_failure
   }
   ```

4. **Error conditions**
   ```bash
   @test "function_name: fails when dependency missing" {
       # Mock missing command
       function required_command() { return 127; }
       export -f required_command

       run function_name
       assert_failure
   }
   ```

## Test Generation Process

1. **Identify functions to test**
   - New functions in `install/lib/*.sh`
   - Modified functions (add regression tests)
   - Bug fixes (test the fix prevents regression)

2. **Determine test file**
   - Map to existing test file: `install/lib/cache.sh` → `install/tests/test-cache.bats`
   - Create new file if needed: `install/lib/new-module.sh` → `install/tests/test-new-module.bats`

3. **Generate test cases**
   - Function existence check
   - Happy path with typical inputs
   - Edge cases (empty input, special chars, etc.)
   - Error conditions (missing deps, invalid input)
   - Integration scenarios if applicable

4. **Use project patterns**
   - Follow naming convention: `function_name: behavior`
   - Use `load test-helper` and `LIB_DIR`
   - Add `skip` for platform-specific tests
   - Mock external commands, don't hit real system

5. **Output format**
   - Create or update `.bats` file
   - Add tests in logical groups
   - Include comments explaining complex tests
   - Ensure tests can run independently

## Example Test Generation

**Given function:**
```bash
validate_package_name() {
    local package="$1"
    [[ "$package" =~ ^[a-zA-Z0-9._-]+$ ]]
}
```

**Generate tests:**
```bash
@test "validate_package_name: accepts valid package names" {
    run validate_package_name "git"
    assert_success

    run validate_package_name "nodejs-lts"
    assert_success

    run validate_package_name "package.name"
    assert_success
}

@test "validate_package_name: rejects invalid characters" {
    run validate_package_name "package with spaces"
    assert_failure

    run validate_package_name "package/slash"
    assert_failure

    run validate_package_name "package$var"
    assert_failure
}

@test "validate_package_name: handles empty input" {
    run validate_package_name ""
    assert_failure
}
```

## Test Coverage Goals

For each function, aim to cover:
- ✅ Function exists and is callable
- ✅ Happy path works with typical input
- ✅ Edge cases handled correctly
- ✅ Errors reported appropriately
- ✅ No unintended side effects

## Context for This Repository

- **Test directory**: `install/tests/`
- **Test helper**: `install/tests/test-helper.bash` (provides `LIB_DIR`, assertions)
- **Run tests**: `make -f test.mk test` or `bats <test-file>`
- **Parallel execution**: Tests run in parallel, keep them independent
- **Bash version**: Tests require Bash 4+
- **Mocking preferred**: Don't call real apt, brew, mise in tests

## What Makes Good Tests

✅ **DO:**
- Test one thing per test case
- Use descriptive test names
- Mock external dependencies
- Keep tests fast and independent
- Add comments for complex test logic

❌ **DON'T:**
- Test implementation details (test behavior, not internals)
- Make tests dependent on execution order
- Call real package managers or network services
- Leave test files or processes behind
- Write tests that only pass on specific platforms (use `skip`)
