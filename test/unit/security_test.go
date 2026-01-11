package unit

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestNoWildcardActions ensures IAM policies don't have wildcard Actions
func TestNoWildcardActions(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err, "Failed to find Terraform files")
	require.Greater(t, len(files), 0, "No Terraform files found")

	wildcardPattern := regexp.MustCompile(`Action\s*=\s*["']?\s*\*\s*["']?`)
	violatingFiles := []string{}

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		if wildcardPattern.MatchString(string(content)) {
			violatingFiles = append(violatingFiles, file)
		}
	}

	assert.Empty(t, violatingFiles, "Found wildcard Actions in IAM policies: %v", violatingFiles)
}

// TestNoWildcardResources ensures IAM policies don't have overly broad Resource wildcards
func TestNoWildcardResources(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err, "Failed to find Terraform files")

	// Allow arn:aws:* but not bare * for resources
	broadWildcardPattern := regexp.MustCompile(`Resource\s*=\s*\[\s*["']\s*\*\s*["']\s*\]`)
	violatingFiles := []string{}

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		if broadWildcardPattern.MatchString(string(content)) {
			violatingFiles = append(violatingFiles, file)
		}
	}

	assert.Empty(t, violatingFiles, "Found broad wildcard Resources in IAM policies: %v", violatingFiles)
}

// TestS3BucketEncryption ensures S3 buckets have encryption configured
func TestS3BucketEncryption(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	s3BucketPattern := regexp.MustCompile(`resource\s+"aws_s3_bucket"\s+`)
	encryptionPattern := regexp.MustCompile(`aws_s3_bucket_server_side_encryption_configuration|sse_algorithm`)

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		contentStr := string(content)
		if s3BucketPattern.MatchString(contentStr) {
			// If there's an S3 bucket, encryption should be configured
			assert.True(t, encryptionPattern.MatchString(contentStr),
				"S3 bucket in %s should have encryption configured", file)
		}
	}
}

// TestPublicAccessBlockOnS3 ensures S3 buckets block public access
func TestPublicAccessBlockOnS3(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	s3BucketPattern := regexp.MustCompile(`resource\s+"aws_s3_bucket"\s+`)
	publicBlockPattern := regexp.MustCompile(`aws_s3_bucket_public_access_block|block_public_acls\s*=\s*true`)

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		contentStr := string(content)
		if s3BucketPattern.MatchString(contentStr) {
			assert.True(t, publicBlockPattern.MatchString(contentStr),
				"S3 bucket in %s should have public access block configured", file)
		}
	}
}

// TestDatabaseEncryption ensures databases have encryption at rest
func TestDatabaseEncryption(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	dynamoDBPattern := regexp.MustCompile(`resource\s+"aws_dynamodb_table"`)
	encryptionPattern := regexp.MustCompile(`sse_specification|kms_key_arn`)

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		contentStr := string(content)
		if dynamoDBPattern.MatchString(contentStr) {
			assert.True(t, encryptionPattern.MatchString(contentStr),
				"DynamoDB table in %s should have encryption configured", file)
		}
	}
}

// TestRDSEncryption ensures RDS databases have encryption
func TestRDSEncryption(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	rdsPattern := regexp.MustCompile(`resource\s+"aws_db_instance"`)
	encryptionPattern := regexp.MustCompile(`storage_encrypted\s*=\s*true`)

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		contentStr := string(content)
		if rdsPattern.MatchString(contentStr) {
			assert.True(t, encryptionPattern.MatchString(contentStr),
				"RDS database in %s should have storage_encrypted = true", file)
		}
	}
}

// TestNoHardcodedSecrets ensures no hardcoded passwords or keys
func TestNoHardcodedSecrets(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	// Patterns for hardcoded secrets
	passwordPattern := regexp.MustCompile(`password\s*=\s*["'](?!var\.|data\.|aws_|local\.)`)
	secretPattern := regexp.MustCompile(`secret\s*=\s*["'](?!var\.|data\.|aws_|local\.)`)
	apiKeyPattern := regexp.MustCompile(`api_key\s*=\s*["'](?!var\.|data\.|aws_|local\.)`)

	violatingFiles := []string{}

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		contentStr := string(content)
		if passwordPattern.MatchString(contentStr) || secretPattern.MatchString(contentStr) || apiKeyPattern.MatchString(contentStr) {
			violatingFiles = append(violatingFiles, file)
		}
	}

	assert.Empty(t, violatingFiles, "Found hardcoded secrets in files: %v", violatingFiles)
}

// TestSecurityGroupRestrictedSSH ensures SSH (port 22) is restricted
func TestSecurityGroupRestrictedSSH(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	sgPattern := regexp.MustCompile(`resource\s+"aws_security_group"`)
	openSSHPattern := regexp.MustCompile(`from_port\s*=\s*22.*?cidr_blocks\s*=\s*\[\s*["']0\.0\.0\.0/0["']\s*\]`)

	violatingFiles := []string{}

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		contentStr := string(content)
		if sgPattern.MatchString(contentStr) && openSSHPattern.MatchString(contentStr) {
			violatingFiles = append(violatingFiles, file)
		}
	}

	assert.Empty(t, violatingFiles, "Found unrestricted SSH access in security groups: %v", violatingFiles)
}

// TestLoggingEnabled ensures CloudTrail/logging is enabled
func TestCloudTrailEnabled(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	cloudtrailPattern := regexp.MustCompile(`resource\s+"aws_cloudtrail"`)
	enabledPattern := regexp.MustCompile(`is_multi_region_trail\s*=\s*true|enable_log_file_validation\s*=\s*true`)

	foundCloudtrail := false
	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		contentStr := string(content)
		if cloudtrailPattern.MatchString(contentStr) {
			foundCloudtrail = true
			assert.True(t, enabledPattern.MatchString(contentStr),
				"CloudTrail in %s should have enable_log_file_validation or multi-region enabled", file)
		}
	}

	assert.True(t, foundCloudtrail, "CloudTrail should be configured in at least one module")
}

// TestKMSKeyRotation ensures KMS keys have rotation enabled
func TestKMSKeyRotation(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	kmsPattern := regexp.MustCompile(`resource\s+"aws_kms_key"`)
	rotationPattern := regexp.MustCompile(`enable_key_rotation\s*=\s*true`)

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		contentStr := string(content)
		if kmsPattern.MatchString(contentStr) {
			assert.True(t, rotationPattern.MatchString(contentStr),
				"KMS key in %s should have key rotation enabled", file)
		}
	}
}

// TestRequiredTags ensures resources have required tags
func TestRequiredTags(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	tagPattern := regexp.MustCompile(`tags\s*=\s*\{`)
	envTagPattern := regexp.MustCompile(`env\s*=`)

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		contentStr := string(content)
		// If tags block exists, should include env tag
		if tagPattern.MatchString(contentStr) {
			assert.True(t, envTagPattern.MatchString(contentStr),
				"Resources in %s should have 'env' tag defined", file)
		}
	}
}

// TestNoPublicRDS ensures RDS instances are not publicly accessible
func TestNoPublicRDS(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	rdsPattern := regexp.MustCompile(`resource\s+"aws_db_instance"`)
	publicAccessPattern := regexp.MustCompile(`publicly_accessible\s*=\s*true`)

	violatingFiles := []string{}

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		contentStr := string(content)
		if rdsPattern.MatchString(contentStr) && publicAccessPattern.MatchString(contentStr) {
			violatingFiles = append(violatingFiles, file)
		}
	}

	assert.Empty(t, violatingFiles, "Found publicly accessible RDS instances: %v", violatingFiles)
}

// TestVPCFlowLogs ensures VPC flow logs are enabled
func TestVPCFlowLogs(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	vpcPattern := regexp.MustCompile(`resource\s+"aws_vpc"`)
	flowLogsPattern := regexp.MustCompile(`aws_flow_log|enable_flow_logs\s*=\s*true`)

	foundVPC := false
	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		contentStr := string(content)
		if vpcPattern.MatchString(contentStr) {
			foundVPC = true
		}
	}

	// Check if flow logs are configured somewhere
	allContent := ""
	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}
		allContent += string(content)
	}

	if foundVPC {
		assert.True(t, flowLogsPattern.MatchString(allContent),
			"VPC flow logs should be configured for network monitoring")
	}
}

// Helper function to find all Terraform files
func findTerraformFiles(dir string) ([]string, error) {
	var files []string

	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Skip .terraform directories
		if info.IsDir() && strings.Contains(path, ".terraform") {
			return filepath.SkipDir
		}

		if !info.IsDir() && strings.HasSuffix(path, ".tf") {
			files = append(files, path)
		}

		return nil
	})

	return files, err
}
