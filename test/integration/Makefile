.PHONY: help test test-all test-verbose coverage clean

# Test timeout (integration tests can take a while)
TIMEOUT ?= 60m

help:
	@echo "Integration Tests - Make Commands"
	@echo "=================================="
	@echo ""
	@echo "  test          - Run all integration tests"
	@echo "  test-verbose  - Run tests with verbose output"
	@echo "  test-<module> - Run specific module test"
	@echo "  coverage      - Generate coverage report"
	@echo "  clean         - Clean test artifacts and state"
	@echo ""
	@echo "Module tests:"
	@echo "  test-bootstrap      test-security       test-vpc"
	@echo "  test-certificates   test-rbac           test-data-store"
	@echo "  test-firewall       test-secrets        test-vpc-endpoints"
	@echo "  test-compute        test-monitoring"
	@echo ""
	@echo "Configuration:"
	@echo "  TIMEOUT=60m   - Test timeout (default: 60m)"
	@echo ""
	@echo "Requirements:"
	@echo "  - AWS credentials configured"
	@echo "  - Terraform >= 1.7.5"

# Default: run all integration tests
test: test-all

test-all:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Running all integration tests..."
	@echo "Timeout: $(TIMEOUT)"
	@echo "═══════════════════════════════════════════════════════════════"
	go test -v -timeout $(TIMEOUT) ./...

test-verbose:
	go test -v -timeout $(TIMEOUT) ./...

# Individual module tests
test-bootstrap:
	@echo "Testing bootstrap module..."
	go test -v -timeout 30m -run "Bootstrap" ./...

test-security:
	@echo "Testing security module..."
	go test -v -timeout 30m -run "Security" ./...

test-vpc:
	@echo "Testing VPC module..."
	go test -v -timeout 30m -run "VPC" ./...

test-certificates:
	@echo "Testing certificates module..."
	go test -v -timeout 30m -run "Certificates" ./...

test-rbac:
	@echo "Testing RBAC module..."
	go test -v -timeout 30m -run "RBAC" ./...

test-data-store:
	@echo "Testing data_store module..."
	go test -v -timeout 30m -run "DataStore" ./...

test-firewall:
	@echo "Testing firewall module..."
	go test -v -timeout 30m -run "Firewall" ./...

test-secrets:
	@echo "Testing secrets module..."
	go test -v -timeout 30m -run "Secrets" ./...

test-vpc-endpoints:
	@echo "Testing vpc-endpoints module..."
	go test -v -timeout 30m -run "VPCEndpoints" ./...

test-compute:
	@echo "Testing compute module..."
	go test -v -timeout 30m -run "Compute" ./...

test-monitoring:
	@echo "Testing monitoring module..."
	go test -v -timeout 30m -run "Monitoring" ./...

# Coverage
coverage:
	@echo "Generating integration test coverage report..."
	go test -coverprofile=coverage.out -covermode=atomic -timeout $(TIMEOUT) ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

# Cleanup
clean:
	rm -f coverage.out coverage.html
	go clean -testcache
	@echo "Cleaning test terraform state..."
	find ../../envs/test/integration -name "*.tfstate*" -delete 2>/dev/null || true
	find ../../envs/test/integration -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find ../../envs/test/integration -name ".terraform.lock.hcl" -delete 2>/dev/null || true

.DEFAULT_GOAL := help
