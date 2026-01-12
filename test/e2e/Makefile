.PHONY: help test test-keep test-verbose clean destroy-resources

# Configuration
TIMEOUT ?= 120m
SKIP_E2E_CLEANUP ?= false

help:
	@echo "E2E Tests - Make Commands"
	@echo "========================="
	@echo ""
	@echo "  test          - Run E2E tests (auto-cleanup on completion)"
	@echo "  test-keep     - Run E2E tests WITHOUT cleanup (keep resources)"
	@echo "  test-verbose  - Run tests with extra verbose output"
	@echo "  clean         - Clean test artifacts and state files"
	@echo "  destroy       - Manually destroy E2E test resources"
	@echo ""
	@echo "Configuration:"
	@echo "  TIMEOUT=120m           - Test timeout (default: 120m)"
	@echo "  SKIP_E2E_CLEANUP=false - Skip cleanup after tests"
	@echo ""
	@echo "Examples:"
	@echo "  make test                         # Run with auto-cleanup"
	@echo "  make test-keep                    # Keep resources for debugging"
	@echo "  make SKIP_E2E_CLEANUP=true test   # Same as test-keep"
	@echo "  make destroy                      # Manually cleanup resources"
	@echo ""
	@echo "IMPORTANT:"
	@echo "  - E2E tests deploy REAL AWS resources (costs money!)"
	@echo "  - Use 'test-keep' to inspect deployed resources"
	@echo "  - Always run 'destroy' when done debugging"
	@echo ""
	@echo "Requirements:"
	@echo "  - AWS credentials configured"
	@echo "  - Terraform >= 1.7.5"
	@echo "  - ~30 minutes for full deployment"

# Default: run E2E tests with cleanup
test:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Running E2E tests (full stack deployment)..."
	@echo "SKIP_E2E_CLEANUP=$(SKIP_E2E_CLEANUP)"
	@echo "Timeout: $(TIMEOUT)"
	@echo "═══════════════════════════════════════════════════════════════"
	SKIP_E2E_CLEANUP=$(SKIP_E2E_CLEANUP) go test -v -timeout $(TIMEOUT) ./...

# Run tests but KEEP resources for debugging
test-keep:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Running E2E tests (KEEPING RESOURCES)..."
	@echo "WARNING: Resources will NOT be destroyed after tests!"
	@echo "Run 'make destroy' when done debugging."
	@echo "Timeout: $(TIMEOUT)"
	@echo "═══════════════════════════════════════════════════════════════"
	SKIP_E2E_CLEANUP=true go test -v -timeout $(TIMEOUT) ./...

test-verbose:
	@echo "Running E2E tests (verbose)..."
	SKIP_E2E_CLEANUP=$(SKIP_E2E_CLEANUP) TF_LOG=INFO go test -v -timeout $(TIMEOUT) ./...

# Manually destroy E2E test resources
destroy:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Destroying E2E test resources..."
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Destroying monitoring..."
	-cd ../../envs/test/e2e/monitoring && terraform destroy -auto-approve 2>/dev/null || true
	@echo "Destroying compute..."
	-cd ../../envs/test/e2e/compute && terraform destroy -auto-approve 2>/dev/null || true
	@echo "Destroying vpc-endpoints..."
	-cd ../../envs/test/e2e/vpc-endpoints && terraform destroy -auto-approve 2>/dev/null || true
	@echo "Destroying secrets..."
	-cd ../../envs/test/e2e/secrets && terraform destroy -auto-approve 2>/dev/null || true
	@echo "Destroying firewall..."
	-cd ../../envs/test/e2e/firewall && terraform destroy -auto-approve 2>/dev/null || true
	@echo "Destroying data_store..."
	-cd ../../envs/test/e2e/data_store && terraform destroy -auto-approve 2>/dev/null || true
	@echo "Destroying rbac-authorization..."
	-cd ../../envs/test/e2e/rbac-authorization && terraform destroy -auto-approve 2>/dev/null || true
	@echo "Destroying certificates..."
	-cd ../../envs/test/e2e/certificates && terraform destroy -auto-approve 2>/dev/null || true
	@echo "Destroying vpc..."
	-cd ../../envs/test/e2e/vpc && terraform destroy -auto-approve 2>/dev/null || true
	@echo "Destroying security..."
	-cd ../../envs/test/e2e/security && terraform destroy -auto-approve 2>/dev/null || true
	@echo "Destroying bootstrap..."
	-cd ../../envs/test/e2e/bootstrap && terraform destroy -auto-approve 2>/dev/null || true
	@echo "E2E resource destruction complete!"

# Clean test state files
clean:
	@echo "Cleaning E2E test artifacts..."
	rm -f coverage.out coverage.html
	go clean -testcache
	@echo "Cleaning E2E terraform state..."
	find ../../envs/test/e2e -name "*.tfstate*" -delete 2>/dev/null || true
	find ../../envs/test/e2e -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find ../../envs/test/e2e -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@echo "Clean complete!"

# Status check - show what's deployed
status:
	@echo "E2E Test Environment Status:"
	@echo "============================"
	@for dir in bootstrap security vpc certificates rbac-authorization data_store firewall secrets vpc-endpoints compute monitoring; do \
		if [ -f "../../envs/test/e2e/$$dir/terraform.tfstate" ]; then \
			echo "✓ $$dir - deployed"; \
		else \
			echo "○ $$dir - not deployed"; \
		fi; \
	done

.DEFAULT_GOAL := help
