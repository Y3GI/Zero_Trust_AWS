# Zero Trust AWS - Test Suite

Comprehensive test suite using Terratest to validate all Terraform modules and Zero Trust architecture principles.

## Test Coverage

### Module Tests (Unit Tests)
- ✅ **bootstrap_test.go** - S3 state backend and DynamoDB locking
- ✅ **vpc_test.go** - VPC, subnets, gateways, route tables
- ✅ **vpc_endpoints_test.go** - VPC endpoints (SSM, Secrets, KMS, etc.)
- ✅ **security_test.go** - IAM roles, KMS encryption, policies
- ✅ **secrets_test.go** - Secrets Manager, password complexity
- ✅ **certificates_test.go** - ACM certificates, DNS validation
- ✅ **rbac_test.go** - IAM groups, role-based access control
- ✅ **firewall_test.go** - Security groups, NACLs, rules
- ✅ **compute_test.go** - EC2 instances, EBS encryption, user data
- ✅ **data_store_test.go** - RDS PostgreSQL, encryption, backups
- ✅ **monitoring_test.go** - CloudTrail, CloudWatch, alarms, budgets

### Integration Tests
- ✅ **integration_test.go** - Bootstrap + VPC integration
- ✅ **full_integration_test.go** - Complete infrastructure deployment (all 11 modules)
- ✅ **Zero Trust principles validation** - No public IPs, encryption, least privilege

## Prerequisites

### Install Go
```bash
# Download and install Go 1.21+
https://go.dev/dl/

# Verify installation
go version
```

### Install Dependencies
```bash
cd Zero_Trust_AWS

# Initialize Go module
go mod init github.com/yourusername/zero-trust-aws

# Download dependencies
go get github.com/gruntwork-io/terratest/modules/terraform
go get github.com/stretchr/testify/assert
go get github.com/gruntwork-io/terratest/modules/aws

# Tidy up dependencies
go mod tidy
```

### AWS Credentials
Ensure AWS CLI is configured:
```bash
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region: us-east-1
```

## Running Tests

### Run All Tests
```bash
go test -v ./test/ -timeout 30m
```

### Run Specific Module Test
```bash
# Test bootstrap module
go test -v ./test/ -run TestBootstrapModule -timeout 30m

# Test VPC module
go test -v ./test/ -run TestVPCModule -timeout 30m

# Test security module
go test -v ./test/ -run TestSecurityModule -timeout 30m
```

### Run Integration Tests Only
```bash
go test -v ./test/ -run TestIntegration -timeout 30m
```

### Run Full Stack Integration Test
```bash
# This deploys entire infrastructure - takes 20-30 minutes
go test -v ./test/ -run TestFullIntegration -timeout 40m
```

### Skip Long-Running Tests
```bash
# Skip integration tests (only run unit tests)
go test -v ./test/ -short -timeout 10m
```

### Run Tests in Parallel
```bash
# Run tests concurrently (use with caution - can hit AWS limits)
go test -v ./test/ -parallel 4 -timeout 30m
```

## Test Structure

### Unit Test Pattern
```go
func TestModuleName(t *testing.T) {
    t.Parallel() // Run in parallel with other tests
    
    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/module-name",
        Vars: map[string]interface{}{
            "variable1": "value1",
        },
    })
    
    defer terraform.Destroy(t, terraformOptions) // Cleanup
    terraform.InitAndPlan(t, terraformOptions)   // Validate
    
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_resource_type.name")
}
```

### Integration Test Pattern
```go
func TestFullIntegration(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping integration test in short mode")
    }
    
    // Deploy modules in dependency order
    // 1. Bootstrap
    // 2. VPC
    // 3. Security
    // ...
    
    // Validate resources exist
    vpcID := terraform.Output(t, vpcOptions, "vpc_id")
    assert.NotEmpty(t, vpcID)
}
```

## What Each Test Validates

### bootstrap_test.go
- S3 bucket created with versioning
- DynamoDB table created for state locking
- Bucket has server-side encryption
- Public access blocked

### vpc_test.go
- VPC created with correct CIDR
- Subnets created in specified AZs
- Internet Gateway attached
- NAT Gateway created with Elastic IP
- Route tables configured correctly

### vpc_endpoints_test.go
- 8 interface endpoints created (SSM, Secrets, KMS, etc.)
- 1 S3 gateway endpoint created
- Endpoints in correct subnets
- Private DNS enabled

### security_test.go
- IAM role created with trust policy
- Instance profile created
- KMS key created with auto-rotation
- Managed policies attached (SSM, CloudWatch, Secrets)

### secrets_test.go
- Secrets Manager secret created
- Password meets complexity requirements (32 chars, special chars)
- Secret encrypted with KMS

### certificates_test.go
- ACM certificate created
- DNS validation method configured
- Wildcard domain supported

### rbac_test.go
- IAM groups created (Developers, Operators, Auditors)
- Policies attached to groups
- Least privilege access enforced

### firewall_test.go
- Security groups created (VPC endpoints, EC2, RDS)
- NACLs created for all subnet tiers
- Security group rules correct (HTTPS, PostgreSQL)
- Deny-by-default enforced

### compute_test.go
- EC2 instance created with correct type (t3.micro)
- No public IP assigned
- EBS volume encrypted with KMS
- IAM instance profile attached
- User data configured for SSM Agent

### data_store_test.go
- RDS instance created (db.t3.micro)
- Storage encrypted with KMS
- Backup retention configured (7 days)
- Not publicly accessible
- Multi-AZ option available

### monitoring_test.go
- CloudTrail enabled (multi-region)
- Log file validation enabled
- CloudWatch log groups created
- Alarms configured (unauthorized access, high CPU)
- SNS topics created
- Budget alerts configured

### full_integration_test.go
- All modules deploy successfully in order
- Resources connect correctly (VPC → Endpoints → Compute)
- Zero Trust principles validated:
  - No public IPs on EC2/RDS
  - All data encrypted (at rest and in transit)
  - Least privilege IAM
  - Network segmentation
  - Comprehensive logging

## Test Output Examples

### Successful Test
```
=== RUN   TestBootstrapModule
=== PAUSE TestBootstrapModule
=== CONT  TestBootstrapModule
TestBootstrapModule 2024-01-07 10:00:00 terraform [init -upgrade=false]
TestBootstrapModule 2024-01-07 10:00:05 Terraform initialized
TestBootstrapModule 2024-01-07 10:00:05 terraform [plan]
TestBootstrapModule 2024-01-07 10:00:10 Plan: 2 to add, 0 to change, 0 to destroy
--- PASS: TestBootstrapModule (15.23s)
PASS
```

### Failed Test
```
=== RUN   TestVPCModule
=== PAUSE TestVPCModule
=== CONT  TestVPCModule
TestVPCModule 2024-01-07 10:00:00 terraform [init -upgrade=false]
TestVPCModule 2024-01-07 10:00:05 terraform [plan]
    vpc_test.go:45: 
            Error Trace:	vpc_test.go:45
            Error:      	Should contain: "aws_vpc.main"
            Test:       	TestVPCModule
--- FAIL: TestVPCModule (10.15s)
FAIL
```

## Troubleshooting

### Error: "AWS credentials not found"
```bash
# Configure AWS credentials
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### Error: "Timeout waiting for resource"
```bash
# Increase timeout
go test -v ./test/ -timeout 60m
```

### Error: "Resource already exists"
```bash
# Clean up existing resources
cd envs/dev/<module>
terraform destroy -auto-approve

# Or force cleanup
aws s3 rb s3://zero-trust-terraform-state-* --force
```

### Error: "Rate limit exceeded"
```bash
# Don't run tests in parallel
go test -v ./test/ -parallel 1

# Or add delays between tests
# Add time.Sleep(30 * time.Second) in tests
```

## Best Practices

1. **Always run `terraform destroy`** after tests (use `defer`)
2. **Use unique resource names** to avoid conflicts
3. **Run in isolated AWS account** to prevent interference
4. **Set proper timeouts** (30-40 minutes for full stack)
5. **Use parallel tests carefully** (can hit AWS rate limits)
6. **Clean up resources** even if tests fail
7. **Mock expensive resources** for quick feedback (use `terraform plan`)

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Terraform Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.6.0
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Run unit tests
        run: go test -v ./test/ -short -timeout 10m
      
      - name: Run integration tests
        run: go test -v ./test/ -run TestIntegration -timeout 30m
```

## Cost Considerations

Running tests will incur AWS charges:
- **Unit tests** (plan only): ~$0 (no resources created)
- **Integration tests**: ~$5-10 per run (resources created for 30 min)
- **Full stack test**: ~$10-15 per run (all resources for 30-40 min)

**Tip**: Use `terraform plan` tests (no `apply`) for faster, cheaper validation.

## Next Steps

1. Run unit tests to validate module syntax
2. Run integration test to validate connectivity
3. Run full stack test to validate entire deployment
4. Add custom tests for your specific requirements
5. Integrate with CI/CD pipeline

## Support

- Check test logs for detailed error messages
- Review Terraform plan output
- Validate AWS credentials and permissions
- Ensure resources are cleaned up after failed tests

---

**Quick Commands:**
```bash
# Run all unit tests (fast, no AWS resources)
go test -v ./test/ -short

# Run specific module test
go test -v ./test/ -run TestVPCModule

# Run full integration test (slow, creates resources)
go test -v ./test/ -run TestFullIntegration -timeout 40m
```