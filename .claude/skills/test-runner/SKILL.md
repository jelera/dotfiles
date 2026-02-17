---
name: test-runner
description: Run BATS tests for changed shell scripts
---

When shell scripts in the dotfiles repository are modified, run the relevant BATS tests to ensure changes don't break functionality.

## Usage

/test-runner [test-file]

If no test file specified, determine which tests to run based on recent changes.

## Test Mapping

Map source files to their corresponding test files:

- `install/lib/cache.sh` → `install/tests/test-cache.bats`
- `install/lib/verification.sh` → `install/tests/test-verification.bats`
- `install/lib/backend-mise.sh` → `install/tests/test-backend-mise.bats`
- `install/lib/backend-homebrew.sh` → `install/tests/test-backend-homebrew.bats`
- `install/lib/backend-apt.sh` → `install/tests/test-backend-apt.bats`
- `install/lib/backend-ppa.sh` → `install/tests/test-backend-ppa.bats`
- `install/lib/manifest-parser.sh` → `install/tests/test-manifest-parser.bats`
- `install/packages-manifest.sh` → `install/tests/test-schema-validation.bats`
- Any `install/*.sh` changes → `install/tests/test-integration.bats`

## Workflow

1. **Identify changes**: Check git status or ask user which files were modified
2. **Map to tests**: Use the mapping above to find relevant test files
3. **Run tests**: Execute using `make -f test.mk test` (full suite) or `bats <specific-test-file>` (single test)
4. **Report results**:
   - Show pass/fail count
   - Display any test failures with details
   - Suggest fixes if tests fail

## Examples

**After editing cache.sh:**
```bash
bats install/tests/test-cache.bats
```

**After editing multiple install scripts:**
```bash
make -f test.mk test
```

**Run specific test:**
```bash
bats install/tests/test-integration.bats
```

## Notes

- Tests use BATS (Bash Automated Testing System)
- Full test suite can be run with: `make -f test.mk test`
- Integration tests should run after any install script changes
- Test results show which assertions failed for easier debugging
