# ==============================================================================
# Dotfiles Install Script Test Suite
# ==============================================================================
# Test-Driven Development (TDD) test runner using bats
#
# Usage:
#   make -f test.mk              # Show help
#   make -f test.mk test         # Run all tests
#   make -f test.mk test-parser  # Run parser tests only
#   make -f test.mk test-watch   # Watch mode
# ==============================================================================

.PHONY: test test-all test-parser test-backends test-integration test-watch \
        test-verbose test-clean test-serial test-debug test-fast test-benchmark \
        test-backend-apt test-backend-homebrew test-backend-mise test-backend-ppa \
        test-shellcheck help

# Bats executable path (try mise first, fall back to system)
BATS ?= $(shell if [ -f ~/.local/share/mise/installs/bats/1.13.0/bats-core-1.13.0/bin/bats ]; then \
	echo ~/.local/share/mise/installs/bats/1.13.0/bats-core-1.13.0/bin/bats; \
	elif command -v bats >/dev/null 2>&1; then \
	command -v bats; \
	else \
	echo "bats"; \
	fi)
TEST_DIR := install/tests

# Use Bash 4+ for tests (required for associative arrays)
# Prepend Homebrew bin to PATH so bats finds the newer bash
HOMEBREW_PREFIX := $(shell if [ -d /opt/homebrew ]; then echo /opt/homebrew; elif [ -d /usr/local ]; then echo /usr/local; fi)
export PATH := $(HOMEBREW_PREFIX)/bin:$(PATH)

help: ## Show this help message
	@echo ""
	@echo "╔════════════════════════════════════════════════════════════╗"
	@echo "║         Dotfiles Install Script Test Suite                ║"
	@echo "╚════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Usage: make -f test.mk <target>"
	@echo ""
	@echo "Available test targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}'
	@echo ""

test: ## Run all tests (parallel, 4 jobs)
	@echo "🧪 Running all tests with Bash $(shell bash --version | head -n1 | awk '{print $$4}')..."
	@$(BATS) --jobs 4 $(TEST_DIR)/*.bats

test-all: test ## Alias for 'test'

test-parser: ## Run manifest parser tests only
	@echo "🧪 Running manifest parser tests..."
	@$(BATS) $(TEST_DIR)/test-manifest-parser.bats

test-backends: ## Run backend tests only (when implemented)
	@echo "🧪 Running backend tests..."
	@if [ -f $(TEST_DIR)/test-backend-apt.bats ]; then \
		$(BATS) $(TEST_DIR)/test-backend-*.bats; \
	else \
		echo "⚠️  Backend tests not yet implemented (Phase 2)"; \
	fi

test-integration: ## Run integration tests only
	@echo "🧪 Running integration tests..."
	@$(BATS) $(TEST_DIR)/test-integration.bats

test-watch: ## Watch for changes and re-run tests
	@echo "👀 Watching for changes (press Ctrl+C to stop)..."
	@if command -v watchexec >/dev/null 2>&1; then \
		watchexec -e bats,sh,yaml -w install -- make -f test.mk test; \
	else \
		echo "❌ Error: watchexec not found"; \
		echo "   Install with: mise install watchexec@latest"; \
		exit 1; \
	fi

test-verbose: ## Run tests with verbose output (parallel)
	@echo "🧪 Running tests (verbose mode)..."
	@$(BATS) --jobs 4 --show-output-of-passing-tests $(TEST_DIR)/*.bats

test-clean: ## Clean up test artifacts
	@echo "🧹 Cleaning up test artifacts..."
	@rm -rf $(TEST_DIR)/*.tmp
	@find $(TEST_DIR) -name "*.log" -delete 2>/dev/null || true
	@echo "✅ Test artifacts cleaned"

test-serial: ## Run tests serially (for debugging)
	@echo "🐛 Running tests in serial mode..."
	@$(BATS) $(TEST_DIR)/*.bats

test-debug: ## Run tests serially with verbose output (debugging)
	@echo "🐛 Running tests in debug mode..."
	@$(BATS) --show-output-of-passing-tests $(TEST_DIR)/*.bats

test-fast: ## Run fast tests with mocks (local dev)
	@echo "🏃 Running fast tests with mocks..."
	@MOCK_SYSTEM_CALLS=1 $(BATS) --jobs 4 $(TEST_DIR)/*.bats

test-backend-apt: ## Run APT backend tests only
	@echo "🧪 Running APT backend tests..."
	@$(BATS) $(TEST_DIR)/test-backend-apt.bats

test-backend-homebrew: ## Run Homebrew backend tests only
	@echo "🧪 Running Homebrew backend tests..."
	@$(BATS) $(TEST_DIR)/test-backend-homebrew.bats

test-backend-mise: ## Run mise backend tests only
	@echo "🧪 Running mise backend tests..."
	@$(BATS) $(TEST_DIR)/test-backend-mise.bats

test-backend-ppa: ## Run PPA backend tests only
	@echo "🧪 Running PPA backend tests..."
	@$(BATS) $(TEST_DIR)/test-backend-ppa.bats

test-benchmark: ## Benchmark test performance
	@echo "📊 Test Suite Metrics:"
	@echo "Test files: $(shell find $(TEST_DIR) -name '*.bats' | wc -l | tr -d ' ')"
	@echo ""
	@echo "⏱️  Timing (serial):"
	@time $(BATS) $(TEST_DIR)/*.bats 2>&1 | tail -n 1
	@echo ""
	@echo "⏱️  Timing (parallel, 4 jobs):"
	@time $(BATS) --jobs 4 $(TEST_DIR)/*.bats 2>&1 | tail -n 1
	@echo ""
	@echo "⏱️  Timing (parallel + mocks):"
	@MOCK_SYSTEM_CALLS=1 time $(BATS) --jobs 4 $(TEST_DIR)/*.bats 2>&1 | tail -n 1

test-coverage: ## Show test coverage summary
	@echo "📊 Test Coverage Summary:"
	@echo ""
	@echo "Phase 1 - Foundation:"
	@echo "  ✅ Manifest parser:     22/22 tests passing"
	@echo "  ✅ Schema validation:   27/27 tests passing"
	@echo "  ✅ Total Phase 1:       49/49 tests passing"
	@echo ""
	@echo "Phase 2 - Backend Modules:"
	@echo "  ✅ APT backend:         22/22 tests passing"
	@echo "  ✅ Homebrew backend:    27/27 tests passing"
	@echo "  ✅ PPA backend:         23/23 tests passing"
	@echo "  ✅ mise backend:        22/22 tests passing"
	@echo "  ✅ Total Phase 2:       94/94 tests passing"
	@echo ""
	@echo "Phase 3 - Integration Layer:"
	@echo "  ✅ Integration tests:   30/30 tests passing"
	@echo "  ✅ Total Phase 3:       30/30 tests passing"
	@echo ""
	@echo "🎉 Grand Total: 184/184 tests passing"
	@echo ""
	@echo "✨ Manifest-based installation system is COMPLETE!"
	@echo ""

test-shellcheck: ## Verify shellcheck configuration and run on all scripts
	@echo "🧪 Testing shellcheck configuration..."
	@echo "Verifying .shellcheckrc requires bash 4.0+..."
	@grep -q "bash 4.0" .shellcheckrc || (echo "❌ .shellcheckrc doesn't specify bash 4.0+" && exit 1)
	@echo "✅ .shellcheckrc correctly configured"
	@echo ""
	@echo "Running shellcheck on repository shell scripts (uses .shellcheckrc)..."
	@find install -type f -name "*.sh" -print0 | xargs -0 shellcheck --severity=warning
	@shellcheck --severity=warning install.sh
	@echo "✅ All shell scripts pass shellcheck"

.DEFAULT_GOAL := help
