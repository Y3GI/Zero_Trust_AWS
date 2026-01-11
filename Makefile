.PHONY: help test test-unit test-integration test-all coverage validate deploy destroy clean build

help:
	@echo "ZTNA Zero Trust AWS - Make Commands"
	@echo "===================================="
	@echo "test              - Run unit tests (security & compliance)"
	@echo "test-unit         - Run only unit tests"
	@echo "test-integration  - Run integration tests (requires AWS)"
	@echo "test-all          - Run all tests"
	@echo "coverage          - Generate test coverage report"
	@echo "validate          - Run build.sh validation"
	@echo "build             - Run build.sh"
	@echo "deploy            - Deploy infrastructure"
	@echo "destroy           - Destroy infrastructure"
	@echo "clean             - Clean build artifacts and caches"
	@echo ""
	@echo "Examples:"
	@echo "  make test              # Quick unit tests (2-5 sec)"
	@echo "  make test-integration  # Full integration tests (requires AWS, 5-10 min)"
	@echo "  make coverage          # Generate coverage report"

# Unit Tests - Fast, no AWS needed
test: test-unit

test-unit:
	@echo "Running unit tests (security & compliance)..."
	cd test/unit && go test -v -race ./...

# Integration Tests - Full deployment test
test-integration:
	@echo "Running integration tests (requires AWS credentials)..."
	cd test && go test -v -timeout 60m ./...

# All tests
test-all: test-unit test-integration

# Coverage report
coverage:
	@echo "Generating test coverage report..."
	cd test/unit && go test -coverprofile=coverage.out -covermode=atomic ./...
	cd test/unit && go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: test/unit/coverage.html"

# Build/Validation
build:
	@echo "Running build validation..."
	bash scripts/build.sh

validate: build

# Deployment
deploy:
	@echo "Deploying infrastructure..."
	bash scripts/deploy.sh

destroy:
	@echo "Destroying infrastructure..."
	bash scripts/destroy.sh

# Cleanup
clean:
	@echo "Cleaning up build artifacts..."
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.tfstate*" -type f -delete 2>/dev/null || true
	find . -name "coverage.out" -delete 2>/dev/null || true
	find . -name "coverage.html" -delete 2>/dev/null || true
	find . -name ".terraform.lock.hcl" -type f -delete 2>/dev/null || true
	@echo "Cleanup complete"

# CI/CD Pipeline (in order)
ci-pipeline: test-unit validate deploy
	@echo "CI/CD pipeline complete!"

.DEFAULT_GOAL := help
