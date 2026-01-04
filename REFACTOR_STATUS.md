# Manifest-Based Installation Refactor - Status

**Last Updated**: 2026-01-04
**Current Phase**: Phase 2 Complete ✅, Ready for Phase 3

## Quick Start for Next Session

```bash
# Run all tests
make -f test.mk test

# View test coverage
make -f test.mk test-coverage

# Test manifest queries
source install/lib/manifest-parser.sh
get_packages_for_profile install/manifests/packages.yaml minimal
validate_manifest_schema install/manifests/packages.yaml
```

## Completed Work

### Phase 1: Foundation ✅ COMPLETE

**What was built**:
1. **Manifest Parser** (`install/lib/manifest-parser.sh`)
   - Full YAML querying library using yq
   - Functions for filtering by profile, platform, category
   - Priority chain resolution
   - Package manager config extraction
   - 22 passing tests

2. **JSON Schema Validation** (`install/schemas/package-manifest.schema.json`)
   - Comprehensive schema definition
   - Validates all manifest fields and constraints
   - Enforces profile rules (packages XOR includes/excludes)
   - Platform and priority value enums
   - PPA format validation (must start with "ppa:")
   - 27 passing tests

3. **Package Manifest** (`install/manifests/packages.yaml`)
   - Defines all packages with metadata
   - 4 installation profiles: full, dev, minimal, remote
   - 4 categories: language_runtimes, general_tools, system_libraries, gui_applications
   - ~70 packages defined with platform filters and priority chains
   - Bulk install groups for optimization

4. **Test Infrastructure**
   - BATS testing framework
   - Test fixtures and helpers
   - Makefile-based test runner (`test.mk`)
   - 49/49 tests passing

**Key Files**:
- `install/lib/manifest-parser.sh` - Parser with validation
- `install/schemas/package-manifest.schema.json` - JSON Schema
- `install/manifests/packages.yaml` - Package definitions
- `install/tests/test-manifest-parser.bats` - Parser tests (22)
- `install/tests/test-schema-validation.bats` - Schema tests (27)
- `test.mk` - Test runner
- `mise/config.toml` - Added pipx:check-jsonschema

**Dependencies Installed**:
```bash
mise install yq@latest                        # YAML processor
mise install bats@latest                      # Test framework
mise install pipx:check-jsonschema@latest     # Schema validator
```

### Phase 2: Backend Modules ✅ COMPLETE

**What was built**:
All 4 package manager backends implemented with comprehensive test coverage using TDD methodology.

**Backends Implemented**:

#### 1. APT Backend (`install/lib/backend-apt.sh`) ✅
**Test Results**: 22/22 tests passing

**Functions**:
- `apt_get_package_name` - Extract package name(s) from manifest
- `apt_check_installed` - Check if package is installed via dpkg
- `apt_install_package` - Install single package with dry-run support
- `apt_install_bulk` - Batch install multiple packages

**Features**:
- Handles single package or packages array
- Checks installation status before installing
- Comprehensive error handling and validation
- Dry-run mode for testing
- Installation summaries

#### 2. Homebrew Backend (`install/lib/backend-homebrew.sh`) ✅
**Test Results**: 27/27 tests passing
**Functions**:
- `brew_get_package_name` - Extract package name from manifest
- `brew_is_cask` - Determine if package is a cask or formula
- `brew_check_installed` - Check installation status
- `brew_install_package` - Install formula or cask with dry-run support
- `brew_add_tap` - Add custom Homebrew taps
- `brew_install_bulk` - Batch install multiple packages

**Features**:
- Automatically distinguishes formulas from casks
- Validates tap name format
- Handles mixed formula/cask installations
- Installation summaries

#### 3. PPA Backend (`install/lib/backend-ppa.sh`) ✅
**Test Results**: 23/23 tests passing
**Functions**:
- `ppa_get_repository` - Extract PPA repository URL from manifest
- `ppa_get_package_name` - Extract package name(s) from manifest
- `ppa_get_gpg_key` - Get optional GPG key URL
- `ppa_check_added` - Check if PPA is already added
- `ppa_add_repository` - Add PPA with optional GPG key
- `ppa_install_package` - Add PPA and install packages

**Features**:
- Validates PPA format (must start with "ppa:")
- Handles optional GPG keys
- Checks if PPA already added before adding
- Automatically runs apt-get update after adding PPA
- Supports multiple packages per PPA

#### 4. mise Backend (`install/lib/backend-mise.sh`) ✅
**Test Results**: 22/22 tests passing
**Functions**:
- `mise_is_managed` - Check if package is managed by mise
- `mise_check_available` - Check if mise command exists
- `mise_check_tool_available` - Check if tool exists in mise registry
- `mise_check_installed` - Check if tool is installed (not just listed)
- `mise_get_version` - Get version to install (defaults to "latest")
- `mise_install_tool` - Install tool with dry-run support
- `mise_sync_with_manifest` - Sync all mise tools in a category

**Features**:
- Distinguishes between listed and actually installed tools
- Handles explicit version specifications
- Syncs entire categories of mise-managed tools
- Gracefully handles mise not being available

**Test Files**:
- `install/tests/test-backend-apt.bats` - APT backend tests (22)
- `install/tests/test-backend-homebrew.bats` - Homebrew backend tests (27)
- `install/tests/test-backend-ppa.bats` - PPA backend tests (23)
- `install/tests/test-backend-mise.bats` - mise backend tests (22)

**TDD Methodology Used**:
All backends were developed using strict Test-Driven Development:
1. ✅ Write failing tests first (Red phase)
2. ✅ Implement minimal code to pass tests (Green phase)
3. ✅ Refactor while keeping tests green (Refactor phase)
4. ✅ Verify no regressions with full test suite

**Common Backend Interface**:
All backends follow a consistent pattern:
```bash
<backend>_install_package(manifest_file, package_name, [dry_run])
<backend>_check_installed(package_name)
<backend>_get_package_name(manifest_file, package_name)
```

**Phase 2 Test Coverage**:
- Total: 94/94 tests passing
- All backends tested with dry-run mode
- Error handling and validation tested
- Edge cases covered (missing files, corrupted manifests, invalid packages)

## Next Steps: Phase 3 - Integration Layer

**Goal**: Replace hardcoded install logic with manifest-driven orchestration

**New File**: `install/packages-manifest.sh`

**Features**:
- Read profile from CLI args
- Query manifest for package list
- Orchestrate backend modules
- Honor priority chains
- Dual-mode support (--use-manifest flag)

## Current Manifest Schema

### Profiles
- **full**: Complete dev environment (all categories)
- **dev**: Headless dev (all except GUI apps)
- **minimal**: Essential CLI only (git, curl, wget, tmux, tree, pinentry)
- **remote**: Lightweight server (minimal + htop + build-essential)

### Categories
- **language_runtimes**: Ruby, Python, Node, Go, etc. (priority: ppa → homebrew → mise)
- **general_tools**: CLI utilities (priority: apt → ppa → homebrew → mise)
- **system_libraries**: Build dependencies (priority: apt only)
- **gui_applications**: Desktop apps (priority: homebrew-cask → flatpak)

### Package Definition Example
```yaml
packages:
  git:
    category: general_tools
    description: "Version control system"
    priority: ["apt", "homebrew"]  # Override category default
    platforms: ["ubuntu", "macos"]  # Optional
    apt:
      package: git
    homebrew:
      package: git
```

## Testing Strategy

### Run Tests
```bash
make -f test.mk help           # Show all commands
make -f test.mk test           # Run all tests
make -f test.mk test-parser    # Parser tests only
make -f test.mk test-verbose   # Verbose output
make -f test.mk test-watch     # Watch mode
make -f test.mk test-coverage  # Coverage summary
```

### Test Structure
```
install/tests/
├── fixtures/
│   └── test-packages.yaml     # Test data
├── test-helper.bash           # Common utilities
├── test-manifest-parser.bats  # Parser tests (22)
└── test-schema-validation.bats # Schema tests (27)
```

## Important Commands

### Validate Manifest
```bash
# Using function
source install/lib/manifest-parser.sh
validate_manifest_schema install/manifests/packages.yaml

# Direct command
check-jsonschema --schemafile install/schemas/package-manifest.schema.json \
  install/manifests/packages.yaml
```

### Query Manifest
```bash
source install/lib/manifest-parser.sh

# Get packages for profile
get_packages_for_profile install/manifests/packages.yaml minimal

# Get packages for platform
get_packages_for_platform install/manifests/packages.yaml ubuntu

# Get package priority chain
get_package_priority install/manifests/packages.yaml git

# Check if managed by mise
is_managed_by_mise install/manifests/packages.yaml ruby
```

## Documentation

All documentation is in `AGENTS.md`:
- Full refactor overview and architecture
- Phase 1, 2, 3 details
- Manifest schema reference
- Testing guide
- Adding packages and profiles
- Migration strategy

## Key Decisions Made

1. **Schema Validation**: Using check-jsonschema via mise (not yq, which lacks schema support)
2. **Version Format**: Accepts both string "1.0" and number 1.0
3. **Profile Types**: Support both category-based (includes/excludes) and explicit (packages array)
4. **Priority Chain**: Per-package overrides category defaults
5. **NO snap**: Explicitly excluded from valid package managers
6. **Graceful Degradation**: Schema validation falls back to basic yq validation if check-jsonschema unavailable

## Known Issues / TODOs

- [ ] None currently - Phase 1 complete and tested

## Git Status

```
M mise/config.toml  # Added check-jsonschema

New files (need to commit):
- install/schemas/package-manifest.schema.json
- install/tests/test-schema-validation.bats
- REFACTOR_STATUS.md (this file)

Modified:
- install/lib/manifest-parser.sh
- install/tests/README.md
- test.mk
- AGENTS.md
```

## Context for AI Assistants

When resuming this refactor:

1. **Phase 1 is complete** - 49/49 tests passing
2. **Next task**: Implement Phase 2 backend modules using TDD
3. **Start with**: APT backend (most common on Ubuntu)
4. **Test first**: Write failing tests, then implement
5. **Reference**: See AGENTS.md for full architecture details
6. **Validate changes**: Run `make -f test.mk test` frequently

## Session Notes

**Session 2026-01-03**:
- Added comprehensive JSON Schema validation
- Implemented validate_manifest_schema() function
- Wrote 27 schema validation tests (all passing)
- Updated all documentation
- Phase 1 now truly complete with 49/49 tests

**Previous session**:
- Implemented manifest parser with yq
- Created package manifest with profiles
- Built test infrastructure
- 22 parser tests passing
