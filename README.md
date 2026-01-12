# Zero Trust AWS Infrastructure

A production-ready Zero Trust Network Architecture (ZTNA) implementation on AWS using Terraform and Infrastructure as Code (IaC) best practices.

## Overview

This project implements a complete Zero Trust security model on AWS with:

- **11 Terraform Modules** - Modular, reusable infrastructure components
- **Multi-Environment Support** - Separate dev and test environments
- **Comprehensive Testing** - Unit, integration, and E2E test suites
- **CI/CD Pipelines** - Automated deployment and testing workflows

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Zero Trust AWS Architecture                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │   Bootstrap  │  │   Security   │  │     VPC      │               │
│  │  S3 + KMS    │  │  IAM + KMS   │  │   Network    │               │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘               │
│         │                 │                 │                        │
│         ▼                 ▼                 ▼                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │  Monitoring  │  │   Secrets    │  │   Firewall   │               │
│  │  CloudTrail  │  │   Manager    │  │   Network    │               │
│  └──────────────┘  └──────────────┘  └──────────────┘               │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │   Compute    │  │  Data Store  │  │     VPC      │               │
│  │  EC2 + ASG   │  │  DynamoDB    │  │  Endpoints   │               │
│  └──────────────┘  └──────────────┘  └──────────────┘               │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐                                 │
│  │    RBAC      │  │ Certificates │                                 │
│  │Authorization │  │   ACM PCA    │                                 │
│  └──────────────┘  └──────────────┘                                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.7.5
- [Go](https://go.dev/dl/) >= 1.21 (for testing)
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- Make

### Commands

```bash
# Show all available commands
make help

# Run unit tests (fast, no AWS needed)
make test

# Run integration tests (requires AWS)
make test-integration

# Deploy infrastructure
make deploy

# Destroy infrastructure
make destroy
```

## Project Structure

```
Zero_Trust_AWS/
├── modules/                 # Reusable Terraform modules
│   ├── bootstrap/          # S3 state backend, CloudTrail bucket
│   ├── security/           # IAM roles, KMS keys
│   ├── vpc/                # VPC, subnets, gateways
│   ├── compute/            # EC2 instances, security groups
│   ├── data_store/         # DynamoDB tables
│   ├── firewall/           # AWS Network Firewall
│   ├── monitoring/         # CloudTrail, CloudWatch, budgets
│   ├── secrets/            # Secrets Manager
│   ├── certificates/       # ACM Private CA
│   ├── rbac-authorization/ # IAM policies for RBAC
│   └── vpc-endpoints/      # VPC endpoints for AWS services
├── envs/                   # Environment configurations
│   ├── dev/               # Development environment
│   └── test/              # Test environments
│       ├── integration/   # Integration test configs
│       └── e2e/           # E2E test configs
├── test/                   # Test suites
│   ├── unit/              # Security & compliance tests
│   ├── integration/       # Module integration tests
│   └── e2e/               # End-to-end tests
├── scripts/               # Deployment scripts
├── .github/workflows/     # CI/CD pipelines
├── docs/                  # Documentation
└── Makefile              # Build automation
```

## Documentation

| Document | Description |
|----------|-------------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Detailed architecture and design |
| [docs/MODULES.md](docs/MODULES.md) | Module reference guide |
| [docs/TESTING.md](docs/TESTING.md) | Testing guide and coverage |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Deployment instructions |
| [docs/SECURITY.md](docs/SECURITY.md) | Security controls and compliance |

## Modules

| Module | Description | Dependencies |
|--------|-------------|--------------|
| `bootstrap` | S3 state bucket, CloudTrail bucket, KMS | None |
| `security` | IAM roles, KMS keys, instance profiles | None |
| `vpc` | VPC, subnets, NAT gateway, route tables | None |
| `data_store` | DynamoDB tables with encryption | security |
| `firewall` | AWS Network Firewall | vpc |
| `compute` | EC2 bastion, app servers | vpc, security |
| `monitoring` | CloudTrail, CloudWatch, budgets | bootstrap, vpc, security |
| `secrets` | Secrets Manager secrets | security |
| `certificates` | ACM Private CA | None |
| `rbac-authorization` | IAM policies for RBAC | None |
| `vpc-endpoints` | VPC endpoints for AWS services | vpc, bootstrap |

## Testing

### Test Levels

| Level | Purpose | Duration | AWS Required |
|-------|---------|----------|--------------|
| Unit | Security & compliance checks | 2-5 sec | No |
| Integration | Individual module deployment | 5-15 min | Yes |
| E2E | Full stack deployment | 30-60 min | Yes |

### Running Tests

```bash
# Unit tests (fast, no AWS)
make test

# Integration tests (one module at a time)
cd test/integration && go test -v -run TestBootstrap -timeout 30m

# E2E tests (full stack)
cd test/e2e && go test -v -run TestE2EStackDeployment -timeout 60m

# E2E cleanup
cd test/e2e && go test -v -run TestE2EStackCleanup -timeout 30m
```

## CI/CD Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `doploy_workflow.yml` | Manual | Deploy infrastructure |
| `destroy_workflow.yml` | Manual | Destroy infrastructure |
| `integration_test_workflow.yml` | Manual | Run integration tests |
| `e2e_test_workflow.yml` | Manual | Run E2E tests |

## Security Features

- ✅ **Encryption at Rest** - KMS encryption for all data stores
- ✅ **Encryption in Transit** - TLS/HTTPS for all communications
- ✅ **VPC Endpoints** - Private connectivity to AWS services
- ✅ **Network Firewall** - Stateful traffic inspection
- ✅ **IAM Least Privilege** - Minimal permissions for all roles
- ✅ **Secrets Management** - Secrets Manager with rotation
- ✅ **Audit Logging** - CloudTrail for all API calls
- ✅ **VPC Flow Logs** - Network traffic logging
- ✅ **mTLS Certificates** - Private CA for service authentication

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

Boyan Stefanov - Fontys University of Applied Sciences
