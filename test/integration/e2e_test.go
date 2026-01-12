package integration

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestE2EStackDeployment tests the full infrastructure deployment in dependency order
// This verifies that all modules can be deployed together with their dependencies resolved
func TestE2EStackDeployment(t *testing.T) {
	t.Parallel()

	// Deploy order matters due to dependencies
	// 1. Bootstrap (creates S3, KMS, CloudTrail)
	// 2. VPC (creates network infrastructure)
	// 3. Security (creates IAM roles, security groups)
	// 4. Compute (depends on VPC for subnets, Security for IAM roles)
	// 5. Data Store (depends on Security for KMS and encryption)
	// 6. Firewall (depends on VPC for security groups)
	// 7. Monitoring (depends on Bootstrap for CloudTrail bucket)
	// 8. Certificates, RBAC, Secrets, VPC Endpoints...

	t.Run("Bootstrap", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/dev/bootstrap",
			TerraformBinary: "terraform",
		})
		defer terraform.Destroy(t, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)

		// Verify bootstrap outputs
		tfStateBucket := terraform.Output(t, terraformOptions, "terraform_state_bucket_name")
		assert.NotEmpty(t, tfStateBucket, "Terraform state bucket should be created")

		cloudTrailBucket := terraform.Output(t, terraformOptions, "cloudtrail_bucket_name")
		assert.NotEmpty(t, cloudTrailBucket, "CloudTrail bucket should be created")

		kmsKeyID := terraform.Output(t, terraformOptions, "kms_key_id")
		assert.NotEmpty(t, kmsKeyID, "KMS key should be created")
	})

	t.Run("VPC", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/dev/vpc",
			TerraformBinary: "terraform",
		})
		defer terraform.Destroy(t, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)

		// Verify VPC outputs
		vpcID := terraform.Output(t, terraformOptions, "vpc_id")
		assert.NotEmpty(t, vpcID, "VPC should be created")

		vpcCIDR := terraform.Output(t, terraformOptions, "vpc_cidr")
		assert.Equal(t, "10.0.0.0/16", vpcCIDR, "VPC CIDR should match configuration")

		publicSubnets := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
		assert.Greater(t, len(publicSubnets), 0, "Public subnets should be created")

		privateSubnets := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
		assert.Greater(t, len(privateSubnets), 0, "Private subnets should be created")

		igwID := terraform.Output(t, terraformOptions, "igw_id")
		assert.NotEmpty(t, igwID, "Internet Gateway should be created")
	})

	t.Run("Security", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/dev/security",
			TerraformBinary: "terraform",
		})
		defer terraform.Destroy(t, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)

		// Verify security outputs
		appRoleName := terraform.Output(t, terraformOptions, "app_instance_role_name")
		assert.NotEmpty(t, appRoleName, "App instance role should be created")

		kmsKeyID := terraform.Output(t, terraformOptions, "kms_key_id")
		assert.NotEmpty(t, kmsKeyID, "KMS key should be created in security module")

		instanceProfile := terraform.Output(t, terraformOptions, "app_instance_profile_name")
		assert.NotEmpty(t, instanceProfile, "Instance profile should be created")
	})

	t.Run("Compute", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/dev/compute",
			TerraformBinary: "terraform",
		})
		defer terraform.Destroy(t, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)

		// Verify compute outputs
		bastionID := terraform.Output(t, terraformOptions, "bastion_instance_id")
		assert.NotEmpty(t, bastionID, "Bastion instance should be created")

		bastionSG := terraform.Output(t, terraformOptions, "bastion_security_group_id")
		assert.NotEmpty(t, bastionSG, "Bastion security group should be created")
	})

	t.Run("DataStore", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/dev/data_store",
			TerraformBinary: "terraform",
		})
		defer terraform.Destroy(t, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)

		// Verify data store outputs
		rdsEndpoint := terraform.Output(t, terraformOptions, "rds_endpoint")
		assert.NotEmpty(t, rdsEndpoint, "RDS endpoint should be created")
	})

	t.Run("Firewall", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/dev/firewall",
			TerraformBinary: "terraform",
		})
		defer terraform.Destroy(t, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)

		// Verify firewall outputs
		sgID := terraform.Output(t, terraformOptions, "security_group_id")
		assert.NotEmpty(t, sgID, "Security group should be created")
	})

	t.Run("Monitoring", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/dev/monitoring",
			TerraformBinary: "terraform",
		})
		defer terraform.Destroy(t, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)

		// Verify monitoring outputs
		cloudWatchLogGroup := terraform.Output(t, terraformOptions, "cloudwatch_log_group_name")
		assert.NotEmpty(t, cloudWatchLogGroup, "CloudWatch log group should be created")
	})

	t.Run("Certificates", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/dev/certificates",
			TerraformBinary: "terraform",
		})
		defer terraform.Destroy(t, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)

		// Verify certificates outputs
		certArn := terraform.Output(t, terraformOptions, "certificate_arn")
		assert.NotEmpty(t, certArn, "Certificate ARN should be created")
	})

	t.Run("RBAC", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/dev/rbac-authorization",
			TerraformBinary: "terraform",
		})
		defer terraform.Destroy(t, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)

		// Verify RBAC outputs
		readOnlyRoleArn := terraform.Output(t, terraformOptions, "read_only_role_arn")
		assert.NotEmpty(t, readOnlyRoleArn, "Read-only role should be created")
	})

	t.Run("Secrets", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/dev/secrets",
			TerraformBinary: "terraform",
		})
		defer terraform.Destroy(t, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)

		// Verify secrets outputs (if any outputs exist)
		// Most secret modules may not have public outputs for security reasons
		t.Log("Secrets module deployed successfully")
	})

	t.Run("VPCEndpoints", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/dev/vpc-endpoints",
			TerraformBinary: "terraform",
		})
		defer terraform.Destroy(t, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)

		// Verify VPC endpoints outputs
		s3EndpointID := terraform.Output(t, terraformOptions, "s3_endpoint_id")
		assert.NotEmpty(t, s3EndpointID, "S3 VPC endpoint should be created")
	})
}

// TestE2ECriticalPath tests only the critical path: Bootstrap → VPC → Security
// This is a faster smoke test for core dependencies
func TestE2ECriticalPath(t *testing.T) {
	t.Parallel()

	var bootstrapOutputs map[string]interface{}
	var vpcOutputs map[string]interface{}
	var securityOutputs map[string]interface{}

	// 1. Deploy Bootstrap
	t.Run("BootstrapDeploy", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/dev/bootstrap",
			TerraformBinary: "terraform",
		})
		defer terraform.Destroy(t, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
		bootstrapOutputs = terraform.OutputAll(t, terraformOptions)
		require.NotNil(t, bootstrapOutputs, "Bootstrap should produce outputs")

		// Verify critical outputs exist
		tfStateBucket := terraform.Output(t, terraformOptions, "terraform_state_bucket_name")
		assert.NotEmpty(t, tfStateBucket, "Terraform state bucket must exist")

		kmsKeyID := terraform.Output(t, terraformOptions, "kms_key_id")
		assert.NotEmpty(t, kmsKeyID, "KMS key must exist for downstream modules")
	})

	// 2. Deploy VPC
	t.Run("VPCDeploy", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/dev/vpc",
			TerraformBinary: "terraform",
		})
		defer terraform.Destroy(t, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
		vpcOutputs = terraform.OutputAll(t, terraformOptions)
		require.NotNil(t, vpcOutputs, "VPC should produce outputs")

		// Verify critical outputs exist
		vpcID := terraform.Output(t, terraformOptions, "vpc_id")
		assert.NotEmpty(t, vpcID, "VPC ID must exist")

		publicSubnets := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
		assert.Greater(t, len(publicSubnets), 0, "Public subnets must exist for compute")
	})

	// 3. Deploy Security
	t.Run("SecurityDeploy", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/dev/security",
			TerraformBinary: "terraform",
		})
		defer terraform.Destroy(t, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
		securityOutputs = terraform.OutputAll(t, terraformOptions)
		require.NotNil(t, securityOutputs, "Security should produce outputs")

		// Verify critical outputs exist
		appRole := terraform.Output(t, terraformOptions, "app_instance_role_name")
		assert.NotEmpty(t, appRole, "App instance role must exist for compute")

		instanceProfile := terraform.Output(t, terraformOptions, "app_instance_profile_name")
		assert.NotEmpty(t, instanceProfile, "Instance profile must exist for compute")
	})

	// 4. Verify dependency chain
	t.Run("DependencyChain", func(t *testing.T) {
		// All critical paths should have completed
		assert.NotEmpty(t, bootstrapOutputs, "Bootstrap outputs should be available")
		assert.NotEmpty(t, vpcOutputs, "VPC outputs should be available")
		assert.NotEmpty(t, securityOutputs, "Security outputs should be available")

		t.Logf("Bootstrap outputs: %v", bootstrapOutputs)
		t.Logf("VPC outputs: %v", vpcOutputs)
		t.Logf("Security outputs: %v", securityOutputs)
	})
}
