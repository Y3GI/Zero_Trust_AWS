.PHONY: help test test-unit test-integration test-e2e test-e2e-keep test-all coverage validate deploy destroy clean build

# Configuration
SKIP_E2E_CLEANUP ?= false

help:
	@echo "ZTNA Zero Trust AWS - Make Commands"
	@echo "===================================="
	@echo ""
	@echo "Testing:"
	@echo "  test              - Run unit tests (security & compliance)"
	@echo "  test-unit         - Run only unit tests (~2-5 sec)"
	@echo "  test-integration  - Run integration tests (~5-10 min, requires AWS)"
	@echo "  test-e2e          - Run E2E tests with cleanup (~15-30 min, requires AWS)"
	@echo "  test-e2e-keep     - Run E2E tests WITHOUT cleanup (keeps resources)"
	@echo "  test-all          - Run all tests (unit + integration + e2e)"
	@echo "  coverage          - Generate test coverage report"
	@echo ""
	@echo "Build & Deploy:"
	@echo "  validate          - Run build.sh validation"
	@echo "  build             - Run build.sh"
	@echo "  deploy            - Deploy infrastructure"
	@echo "  destroy           - Destroy infrastructure"
	@echo ""
	@echo "Cleanup:"
	@echo "  clean             - Clean build artifacts and caches"
	@echo "  clean-test-state  - Clean test terraform state files"
	@echo ""
	@echo "Examples:"
	@echo "  make test                    # Quick unit tests"
	@echo "  make test-integration        # Integration tests (isolated modules)"
	@echo "  make test-e2e                # E2E tests (full stack, auto-cleanup)"
	@echo "  make test-e2e-keep           # E2E tests (keep resources for debugging)"
	@echo "  make SKIP_E2E_CLEANUP=true test-e2e  # Same as test-e2e-keep"

# =============================================================================
# Unit Tests - Fast, no AWS needed
# =============================================================================
test: test-unit

test-unit:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Running unit tests (security & compliance)..."
	@echo "═══════════════════════════════════════════════════════════════"
	cd test/unit && go test -v -race ./...

# =============================================================================
# Integration Tests - Isolated module testing with mock values
# =============================================================================
test-integration:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Running integration tests (requires AWS credentials)..."
	@echo "═══════════════════════════════════════════════════════════════"
	cd test/integration && go test -v -timeout 60m ./...

# =============================================================================
# E2E Tests - Full stack deployment with dependencies
# =============================================================================
test-e2e:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Running E2E tests (full stack deployment)..."
	@echo "SKIP_E2E_CLEANUP=$(SKIP_E2E_CLEANUP)"
	@echo "═══════════════════════════════════════════════════════════════"
	cd test/e2e && SKIP_E2E_CLEANUP=$(SKIP_E2E_CLEANUP) go test -v -timeout 120m ./...

# E2E tests without cleanup (keep resources for debugging)
test-e2e-keep:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Running E2E tests (KEEPING RESOURCES - no cleanup)..."
	@echo "WARNING: Resources will NOT be destroyed after tests!"
	@echo "═══════════════════════════════════════════════════════════════"
	cd test/e2e && SKIP_E2E_CLEANUP=true go test -v -timeout 120m ./...

# =============================================================================
# All tests
# =============================================================================
test-all: test-unit test-integration test-e2e

# =============================================================================
# Coverage report
# =============================================================================
coverage:
	@echo "Generating test coverage report..."
	cd test/unit && go test -coverprofile=coverage.out -covermode=atomic ./...
	cd test/unit && go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: test/unit/coverage.html"

coverage-integration:
	@echo "Generating integration test coverage report..."
	cd test/integration && go test -coverprofile=coverage.out -covermode=atomic -timeout 60m ./...
	cd test/integration && go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: test/integration/coverage.html"

# =============================================================================
# Build/Validation
# =============================================================================
build:
	@echo "Running build validation..."
	bash scripts/build.sh

validate: build

# =============================================================================
# Deployment
# =============================================================================
deploy:
	@echo "Deploying infrastructure..."
	bash scripts/deploy.sh

destroy:
	@echo "Destroying infrastructure..."
	bash scripts/destroy.sh

# =============================================================================
# Cleanup
# =============================================================================
clean:
	@echo "Cleaning up build artifacts..."
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.tfstate*" -type f -delete 2>/dev/null || true
	find . -name "coverage.out" -delete 2>/dev/null || true
	find . -name "coverage.html" -delete 2>/dev/null || true
	find . -name ".terraform.lock.hcl" -type f -delete 2>/dev/null || true
	@echo "Cleanup complete"

clean-test-state:
	@echo "Cleaning test environment terraform state..."
	find envs/test -name "*.tfstate*" -type f -delete 2>/dev/null || true
	find envs/test -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find envs/test -name ".terraform.lock.hcl" -type f -delete 2>/dev/null || true
	@echo "Test state cleanup complete"

# =============================================================================
# CI/CD Pipeline (in order)
# =============================================================================
ci-pipeline: test-unit validate deploy
	@echo "CI/CD pipeline complete!"

ci-full: test-unit test-integration validate deploy test-e2e
	@echo "Full CI/CD pipeline complete!"

.DEFAULT_GOAL := help
