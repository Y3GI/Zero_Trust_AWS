# Testing Guide

Comprehensive testing suite for validating the Zero Trust AWS infrastructure.

## Test Structure

```
test/
├── unit/                    # Fast security & compliance tests
│   ├── security_test.go     # Security policy validation
│   ├── compliance_test.go   # Compliance checks
│   ├── go.mod
│   └── go.sum
├── integration/             # Individual module tests
│   ├── bootstrap_test.go
│   ├── vpc_test.go
│   ├── security_test.go
│   ├── ... (11 module tests)
│   ├── go.mod
│   └── go.sum
└── e2e/                     # Full stack deployment tests
    ├── e2e_test.go
    ├── go.mod
    └── go.sum
```

## Test Levels

### Unit Tests

**Purpose**: Fast validation of Terraform code without deploying to AWS.

**What they check**:
- No wildcard IAM actions (`Action: "*"`)
- No wildcard resources (`Resource: "*"`)
- S3 buckets have encryption configured
- S3 public access is blocked
- No hardcoded secrets in code
- Security groups restrict SSH access
- CloudTrail logging is enabled
- KMS key rotation is enabled
- Required tags are present
- No deprecated resources

**Duration**: 2-5 seconds

**AWS Required**: No

```bash
# Run unit tests
make test

# Or directly
cd test/unit && go test -v ./...
```

### Integration Tests

**Purpose**: Deploy and validate individual modules in isolation.

**Configuration**: Uses `envs/test/integration/` with **mock values** for dependencies, allowing each module to be tested independently.

**What they check**:
- Module deploys successfully
- Outputs are populated correctly
- Resources are created with expected configuration
- Module can be destroyed cleanly

**Duration**: 5-15 minutes per module

**AWS Required**: Yes

```bash
# Run all integration tests
cd test/integration && go test -v ./... -timeout 60m

# Run specific module test
cd test/integration && go test -v -run TestBootstrap -timeout 30m
cd test/integration && go test -v -run TestVPC -timeout 30m
cd test/integration && go test -v -run TestSecurity -timeout 30m
```

### E2E Tests

**Purpose**: Deploy the full infrastructure stack in dependency order.

**Configuration**: Uses `envs/test/e2e/` with **local state references** between modules, simulating a real deployment.

**What they check**:
- All modules deploy in correct dependency order
- Module outputs are properly passed to dependent modules
- Full stack functions together
- Cleanup works in reverse order

**Duration**: 30-60 minutes

**AWS Required**: Yes

```bash
# Deploy full stack
cd test/e2e && go test -v -run TestE2EStackDeployment -timeout 60m

# Clean up after testing
cd test/e2e && go test -v -run TestE2EStackCleanup -timeout 30m

# Run critical path only (Bootstrap → Security → VPC)
cd test/e2e && go test -v -run TestE2ECriticalPath -timeout 30m
```

## Test Environments

### Integration Test Environment (`envs/test/integration/`)

Each module is configured with **mock values** for isolated testing:

```hcl
# Example: envs/test/integration/firewall/main.tf
locals {
    # Mock values - module tests independently
    mock_vpc_id            = "vpc-mock-integration-test"
    mock_public_subnet_ids = ["subnet-mock-public-1a"]
}

module "firewall" {
    source            = "../../../../modules/firewall"
    vpc_id            = local.mock_vpc_id
    public_subnet_ids = local.mock_public_subnet_ids
}
```

### E2E Test Environment (`envs/test/e2e/`)

Modules reference each other via **local state files**:

```hcl
# Example: envs/test/e2e/firewall/main.tf
data "terraform_remote_state" "vpc" {
    backend = "local"
    config = {
        path = "../vpc/terraform.tfstate"
    }
}

module "firewall" {
    source            = "../../../../modules/firewall"
    vpc_id            = data.terraform_remote_state.vpc.outputs.vpc_id
    public_subnet_ids = data.terraform_remote_state.vpc.outputs.public_subnet_ids
}
```

## E2E Test Deployment Order

The E2E tests deploy modules in this dependency order:

```
1. Bootstrap    (independent)
2. Security     (independent)
3. VPC          (independent)
4. Data Store   (depends on: security)
5. Firewall     (depends on: vpc)
6. Compute      (depends on: vpc, security)
7. Monitoring   (depends on: bootstrap, vpc, security)
8. Certificates (independent)
9. RBAC         (independent)
10. Secrets     (depends on: security)
11. VPC Endpoints (depends on: vpc, bootstrap)
```

## Failsafe Cleanup

E2E tests include automatic cleanup on failure:

```go
// If test fails, all deployed modules are destroyed automatically
if os.Getenv("SKIP_E2E_CLEANUP") != "true" {
    t.Cleanup(func() {
        if t.Failed() {
            destroyAllDeployedModules(t)
        }
    })
}
```

**Environment Variables**:
- `SKIP_E2E_CLEANUP=true` - Keep resources after failure (for debugging)

```bash
# Normal run - cleanup on failure
go test -v -run TestE2EStackDeployment ./test/e2e/

# Debug mode - keep resources even on failure
SKIP_E2E_CLEANUP=true go test -v -run TestE2EStackDeployment ./test/e2e/
```

## CI/CD Integration

### GitHub Actions Workflows

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| Integration Test | `integration_test_workflow.yml` | Manual | Run integration tests |
| E2E Test | `e2e_test_workflow.yml` | Manual | Run full stack tests |

### Running in CI

```yaml
# Integration tests
- name: Run Integration Tests
  working-directory: ./test/integration
  run: go test -v ./... -timeout 60m

# E2E tests
- name: Run E2E Tests
  working-directory: ./test/e2e
  run: go test -v -run TestE2EStackDeployment -timeout 60m

- name: Cleanup E2E Resources
  if: always()
  working-directory: ./test/e2e
  run: go test -v -run TestE2EStackCleanup -timeout 30m
```

## Test Coverage

### Module Test Coverage

| Module | Unit | Integration | E2E |
|--------|------|-------------|-----|
| bootstrap | ✅ | ✅ | ✅ |
| security | ✅ | ✅ | ✅ |
| vpc | ✅ | ✅ | ✅ |
| compute | ✅ | ✅ | ✅ |
| data_store | ✅ | ✅ | ✅ |
| firewall | ✅ | ✅ | ✅ |
| monitoring | ✅ | ✅ | ✅ |
| secrets | ✅ | ✅ | ✅ |
| certificates | ✅ | ✅ | ✅ |
| rbac-authorization | ✅ | ✅ | ✅ |
| vpc-endpoints | ✅ | ✅ | ✅ |

### Security Test Coverage

| Check | File | Status |
|-------|------|--------|
| No wildcard IAM actions | `security_test.go` | ✅ |
| No wildcard resources | `security_test.go` | ✅ |
| S3 encryption | `security_test.go` | ✅ |
| S3 public access block | `security_test.go` | ✅ |
| No hardcoded secrets | `security_test.go` | ✅ |
| SSH restrictions | `security_test.go` | ✅ |
| CloudTrail enabled | `security_test.go` | ✅ |
| KMS rotation | `security_test.go` | ✅ |
| Required tags | `compliance_test.go` | ✅ |
| Module existence | `compliance_test.go` | ✅ |

## Troubleshooting

### Common Issues

**Test timeout**:
```bash
# Increase timeout
go test -v ./... -timeout 90m
```

**AWS credentials**:
```bash
# Verify credentials
aws sts get-caller-identity
```

**State file conflicts**:
```bash
# Clean up state files
cd envs/test/e2e && find . -name "*.tfstate*" -delete
```

**Module initialization**:
```bash
# Re-initialize modules
cd envs/test/e2e/bootstrap && terraform init
```

### Debug Mode

```bash
# Enable Terraform debug logging
TF_LOG=DEBUG go test -v -run TestBootstrap ./test/integration/

# Keep resources on failure for investigation
SKIP_E2E_CLEANUP=true go test -v -run TestE2EStackDeployment ./test/e2e/
```
