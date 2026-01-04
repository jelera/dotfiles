# Install Script Test Suite

Test-Driven Development (TDD) test suite for the dotfiles installation scripts.

## Running Tests

From the repository root:

```bash
# Show all available test commands
make -f test.mk help

# Run all tests
make -f test.mk test

# Run specific test suites
make -f test.mk test-parser        # Manifest parser tests
make -f test.mk test-backends      # Backend tests (Phase 2)
make -f test.mk test-integration   # Integration tests (Phase 3)

# Watch mode (re-run tests on file changes)
make -f test.mk test-watch

# Verbose output
make -f test.mk test-verbose

# Test coverage summary
make -f test.mk test-coverage

# Clean up test artifacts
make -f test.mk test-clean
```

## Test Structure

```
install/tests/
├── fixtures/              # Test data and fixtures
│   └── test-packages.yaml # Sample manifest for testing
├── test-helper.bash       # Common utilities and setup/teardown
└── test-*.bats           # Test files (bats format)
```

## Writing Tests

Tests use the [bats](https://github.com/bats-core/bats-core) testing framework.

### Example Test

```bash
#!/usr/bin/env bats

load test-helper

@test "parse_manifest: loads valid YAML" {
    create_test_manifest "$TEST_MANIFEST"

    run parse_manifest "$TEST_MANIFEST"
    [ "$status" -eq 0 ]
}
```

### TDD Workflow

1. **Red**: Write a failing test first
2. **Green**: Implement code to make the test pass
3. **Refactor**: Improve code while keeping tests passing

## Test Coverage

### Phase 1 - Foundation ✅
- ✅ Manifest parser: 22/22 tests passing
  - YAML parsing and validation
  - Category filtering
  - Profile filtering
  - Platform filtering
  - Priority chain resolution
- ✅ Schema validation: 27/27 tests passing
  - JSON Schema validation via check-jsonschema
  - Required field validation
  - Version format validation
  - Profile structure validation
  - Category and priority validation
  - Package definition validation
  - Package manager config validation
  - Bulk install group validation

### Phase 2 - Backend Modules ⏳
- ⏳ APT backend tests (planned)
- ⏳ Homebrew backend tests (planned)
- ⏳ PPA backend tests (planned)

### Phase 3 - Integration ⏳
- ⏳ Full installation flow tests (planned)
- ⏳ Profile-based installation tests (planned)
- ⏳ Dual-mode testing (legacy vs manifest) (planned)

## Dependencies

- **bats** - Testing framework (installed via mise)
- **yq** - YAML processor (installed via mise)
- **check-jsonschema** - JSON Schema validator (installed via mise)

Install with:
```bash
mise install bats@latest yq@latest pipx:check-jsonschema@latest
```

## CI/CD Integration

Tests are designed to run in CI/CD pipelines:

```bash
# Exit with non-zero status if any test fails
make -f test.mk test
```
