.PHONY: help test test-verbose test-race coverage clean

help:
	@echo "Unit Tests - Make Commands"
	@echo "=========================="
	@echo ""
	@echo "  test          - Run all unit tests"
	@echo "  test-verbose  - Run tests with verbose output"
	@echo "  test-race     - Run tests with race detection"
	@echo "  coverage      - Generate coverage report"
	@echo "  clean         - Clean test artifacts"
	@echo ""
	@echo "Tests included:"
	@echo "  - security_test.go    : Security configuration validation"
	@echo "  - compliance_test.go  : Compliance requirements validation"

# Default: run all tests
test:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Running unit tests..."
	@echo "═══════════════════════════════════════════════════════════════"
	go test ./...

test-verbose:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Running unit tests (verbose)..."
	@echo "═══════════════════════════════════════════════════════════════"
	go test -v ./...

test-race:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Running unit tests with race detection..."
	@echo "═══════════════════════════════════════════════════════════════"
	go test -v -race ./...

# Run specific test file
test-security:
	go test -v -run "Security" ./...

test-compliance:
	go test -v -run "Compliance" ./...

# Coverage
coverage:
	@echo "Generating coverage report..."
	go test -coverprofile=coverage.out -covermode=atomic ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

coverage-func:
	@echo "Coverage by function:"
	go test -coverprofile=coverage.out -covermode=atomic ./...
	go tool cover -func=coverage.out

# Cleanup
clean:
	rm -f coverage.out coverage.html
	go clean -testcache

.DEFAULT_GOAL := help
