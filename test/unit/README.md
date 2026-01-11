# Unit Tests - Security & Compliance Checks

Fast, automated security and compliance tests for ZTNA infrastructure as code. These tests run **without deploying to AWS** and provide immediate feedback on code quality.

## Test Coverage

### Security Tests (`security_test.go`)

- **TestNoWildcardActions** - Ensures IAM policies don't use `Action: "*"`
- **TestNoWildcardResources** - Prevents overly broad resource wildcards
- **TestS3BucketEncryption** - Verifies S3 buckets have encryption configured
- **TestPublicAccessBlockOnS3** - Ensures S3 block public access is enabled
- **TestDatabaseEncryption** - Checks DynamoDB has encryption at rest
- **TestRDSEncryption** - Validates RDS `storage_encrypted = true`
- **TestNoHardcodedSecrets** - Detects hardcoded passwords/API keys
- **TestSecurityGroupRestrictedSSH** - Prevents unrestricted SSH (port 22)
- **TestCloudTrailEnabled** - Validates CloudTrail logging is configured
- **TestKMSKeyRotation** - Ensures KMS keys have rotation enabled
- **TestRequiredTags** - Checks resources have required tags (env, etc.)
- **TestNoPublicRDS** - Prevents publicly accessible RDS instances
- **TestVPCFlowLogs** - Verifies VPC flow logs are enabled

### Compliance Tests (`compliance_test.go`)

- **TestModulesExist** - Validates all required modules exist
- **TestEnvironmentConfigurationsExist** - Checks env/dev configs for all modules
- **TestNoDeprecatedResources** - Prevents deprecated AWS resources
- **TestProviderConfiguration** - Ensures proper Terraform provider setup
- **TestBackendConfiguration** - Validates backend state configuration
- **TestNoHardcodedAccountID** - Prevents hardcoded AWS account IDs
- **TestSensitiveVariableDefaults** - Checks sensitive vars are marked
- **TestOutputSecurity** - Validates sensitive outputs are marked
- **TestResourceNamingConvention** - Enforces snake_case naming
- **TestNoCommentedCode** - Prevents excessive commented code
- **TestNoUnnecessaryNullResources** - Discourages null_resource usage

## Running Tests Locally

### Prerequisites

```bash
go version  # Go 1.21+
```

### Run all tests

```bash
cd test/unit
go test -v ./...
```

### Run specific test

```bash
go test -v -run TestNoWildcardActions ./...
```

### Run with coverage

```bash
go test -v -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

### Run in parallel (faster)

```bash
go test -v -parallel 16 ./...
```

## CI/CD Integration

Tests automatically run in GitHub Actions before deployment:

```
quality_gates (Unit Tests)
    ↓
validate (Terraform validate + build.sh)
    ↓
terraform_operations (Deploy)
```

### Workflow Stages

1. **quality_gates** - Run security & compliance unit tests (2-5 seconds)
   - If fails: Block deployment immediately
   - No AWS credentials needed

2. **validate** - Run `terraform validate` + `build.sh` (20-30 seconds)
   - Checks Terraform syntax
   - Generates plans

3. **terraform_operations** - Deploy infrastructure (5-10 minutes)
   - Only runs if both previous stages pass

## Test Output Example

```
=== RUN   TestNoWildcardActions
--- PASS: TestNoWildcardActions (0.02s)
=== RUN   TestS3BucketEncryption
--- PASS: TestS3BucketEncryption (0.01s)
=== RUN   TestKMSKeyRotation
--- PASS: TestKMSKeyRotation (0.01s)
...
ok      github.com/y3gi/zero-trust-aws/test/unit    0.234s
```

## Common Failures & Fixes

### ❌ "Found wildcard Actions in IAM policies"
**Fix**: Replace `Action = "*"` with specific actions:
```hcl
# ❌ Bad
Action = "*"

# ✅ Good
Action = [
  "s3:GetObject",
  "s3:PutObject"
]
```

### ❌ "S3 bucket should have encryption configured"
**Fix**: Add encryption configuration:
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

### ❌ "Found hardcoded secrets"
**Fix**: Use AWS Secrets Manager or Terraform variables:
```hcl
# ❌ Bad
db_password = "MySecurePassword123!"

# ✅ Good
db_password = var.db_password

# In variables.tf:
variable "db_password" {
  type      = string
  sensitive = true
}
```

### ❌ "KMS key should have key rotation enabled"
**Fix**: Enable key rotation:
```hcl
resource "aws_kms_key" "example" {
  enable_key_rotation = true
  # ... other configuration
}
```

## Adding New Tests

To add a security test:

```go
// In security_test.go
func TestMySecurityCheck(t *testing.T) {
    t.Parallel()  // Run in parallel with other tests
    
    terraformDir := "../../modules"
    files, err := findTerraformFiles(terraformDir)
    require.NoError(t, err)
    
    myPattern := regexp.MustCompile(`your pattern here`)
    
    for _, file := range files {
        content, err := ioutil.ReadFile(file)
        if err != nil {
            continue
        }
        
        assert.True(t, myPattern.MatchString(string(content)),
            "Your assertion message for file %s", file)
    }
}
```

## Performance

- **Local run**: ~0.2-0.5 seconds
- **CI/CD run**: ~2-5 seconds
- **All tests parallelized** with `-parallel 16`
- **No AWS API calls** - purely static analysis

## Debugging Failed Tests

Enable verbose output and target specific files:

```bash
# Run specific test with verbose output
go test -v -run TestS3BucketEncryption ./...

# See which files are being checked
go test -v -run Test ./... 2>&1 | grep -i error
```

## Related Documentation

- [Zero_Trust_AWS README](../../README.md)
- [Deployment Guide](../../DEPLOYMENT_GUIDE.md)
- [ZTNA Completeness Checklist](../../ZTNA_COMPLETENESS_CHECKLIST.md)
