---
name: validate-install
description: Validate installation script changes before completion
user-invocable: false
---

After modifying installation scripts (`install.sh`, `install/*.sh`, or `install/lib/*.sh`), validate that changes don't break the installation process.

This skill is Claude-only and runs automatically before claiming work is complete.

## Validation Steps

Run these checks in order. Stop if any fail and fix the issue before proceeding.

### 1. Shellcheck (Syntax & Best Practices)

Verify all shell scripts pass shellcheck with project standards (bash 4.0+, severity=warning):

```bash
shellcheck install.sh install/**/*.sh
```

**Must pass**: No warnings or errors

### 2. Dry-run Installation (Minimal Profile)

Test that the installation script can parse and plan installation without making changes:

```bash
./install.sh --minimal --dry-run
```

**Expected**: Clean exit (status 0), no errors in output

### 3. Core Test Suite

Run the BATS test suite to ensure core functionality works:

```bash
make -f test.mk test
```

**Expected**: All tests pass

## When to Run

Run this validation:
- After editing any file in `install/` directory
- Before creating commits with installation changes
- Before claiming "installation script fixed" or similar
- Before creating PRs that modify install scripts

## If Validation Fails

### Shellcheck failures
- Fix syntax errors immediately
- Address warnings about quoting, logic errors
- Check `.shellcheckrc` for project standards

### Dry-run failures
- Check error messages for clues
- Common issues:
  - Missing function definitions
  - Incorrect sourcing of library files
  - Missing command checks (ensure commands exist before use)

### Test failures
- Read failing test output carefully
- Fix the underlying issue, not the test (unless test is wrong)
- Run single test file for faster iteration: `bats install/tests/test-<name>.bats`

## Notes

- **DO NOT** skip validation to save time - broken install scripts affect all users
- **DO NOT** modify tests to pass without fixing the actual issue
- **DO** fix issues incrementally (shellcheck → dry-run → tests)
- The `--dry-run` flag prevents actual installation, safe to run anywhere
