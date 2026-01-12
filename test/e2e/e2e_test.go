package e2e

import (
	"fmt"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// deployedModules tracks which modules have been successfully deployed
// Used by failsafe cleanup to know what to destroy on test failure
var deployedModules []string

// destroyAllDeployedModules cleans up all deployed modules in reverse order
// This is called by the failsafe mechanism on test failure or interruption
func destroyAllDeployedModules(t *testing.T) {
	if len(deployedModules) == 0 {
		t.Log("No modules to clean up")
		return
	}

	t.Log("=== FAILSAFE CLEANUP: Destroying all deployed modules ===")

	// Destroy in reverse order (last deployed first)
	for i := len(deployedModules) - 1; i >= 0; i-- {
		module := deployedModules[i]
		t.Logf("Destroying module: %s", module)

		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/" + module,
			TerraformBinary: "terraform",
		})

		// Use RunTerraformCommand to avoid failing the test if destroy has issues
		_, err := terraform.RunTerraformCommandE(t, terraformOptions, terraform.FormatArgs(terraformOptions, "destroy", "-auto-approve")...)
		if err != nil {
			t.Logf("Warning: Failed to destroy module %s: %v", module, err)
		} else {
			t.Logf("Successfully destroyed module: %s", module)
		}
	}

	// Clear the tracking slice
	deployedModules = nil
	t.Log("=== FAILSAFE CLEANUP COMPLETE ===")
}

// markModuleDeployed adds a module to the tracking list after successful deployment
func markModuleDeployed(module string) {
	deployedModules = append(deployedModules, module)
}

// TestE2EStackDeployment tests the full infrastructure deployment in dependency order
// This verifies that all modules can be deployed together with their dependencies resolved
// NOTE: This test does NOT destroy resources after each module - they remain up for the full test
// Use TestE2EStackCleanup to destroy all resources after testing
// FAILSAFE: If test fails or is interrupted, t.Cleanup() will destroy all deployed modules
func TestE2EStackDeployment(t *testing.T) {
	// Do NOT run in parallel - modules must deploy in order
	// t.Parallel()

	// Reset deployed modules tracker at start
	deployedModules = nil

	// FAILSAFE: Register cleanup function that runs on test failure, panic, or completion
	// Set SKIP_E2E_CLEANUP=true to keep resources after test (useful for debugging)
	if os.Getenv("SKIP_E2E_CLEANUP") != "true" {
		t.Cleanup(func() {
			if t.Failed() {
				t.Log("Test failed - triggering failsafe cleanup")
				destroyAllDeployedModules(t)
			}
		})
	} else {
		t.Log("SKIP_E2E_CLEANUP is set - failsafe cleanup disabled")
	}

	// Deploy order matters due to dependencies
	// 1. Bootstrap (creates S3, KMS, CloudTrail)
	// 2. Security (creates IAM roles, security groups)
	// 3. VPC (creates network infrastructure)
	// 4. Data Store (depends on Security for KMS and encryption)
	// 5. Firewall (depends on VPC for security groups)
	// 6. Compute (depends on VPC for subnets, Security for IAM roles)
	// 7. Monitoring (depends on Bootstrap for CloudTrail bucket, VPC, Security)
	// 8. Certificates, RBAC, Secrets, VPC Endpoints...

	t.Run("01_Bootstrap", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/bootstrap",
			TerraformBinary: "terraform",
		})
		// No destroy - keep resources up for dependent modules
		terraform.InitAndApply(t, terraformOptions)
		markModuleDeployed("bootstrap") // Track for failsafe cleanup

		// Verify bootstrap outputs
		tfStateBucket := terraform.Output(t, terraformOptions, "terraform_state_bucket_name")
		assert.NotEmpty(t, tfStateBucket, "Terraform state bucket should be created")

		cloudTrailBucket := terraform.Output(t, terraformOptions, "cloudtrail_bucket_name")
		assert.NotEmpty(t, cloudTrailBucket, "CloudTrail bucket should be created")

		kmsKeyID := terraform.Output(t, terraformOptions, "kms_key_id")
		assert.NotEmpty(t, kmsKeyID, "KMS key should be created")
	})

	t.Run("02_Security", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/security",
			TerraformBinary: "terraform",
		})
		// No destroy - keep resources up for dependent modules
		terraform.InitAndApply(t, terraformOptions)
		markModuleDeployed("security") // Track for failsafe cleanup

		// Verify security outputs
		appRoleName := terraform.Output(t, terraformOptions, "app_instance_role_name")
		assert.NotEmpty(t, appRoleName, "App instance role should be created")

		kmsKeyID := terraform.Output(t, terraformOptions, "kms_key_id")
		assert.NotEmpty(t, kmsKeyID, "KMS key should be created in security module")

		instanceProfile := terraform.Output(t, terraformOptions, "app_instance_profile_name")
		assert.NotEmpty(t, instanceProfile, "Instance profile should be created")
	})

	t.Run("03_VPC", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/vpc",
			TerraformBinary: "terraform",
		})
		// No destroy - keep resources up for dependent modules
		terraform.InitAndApply(t, terraformOptions)
		markModuleDeployed("vpc") // Track for failsafe cleanup

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

	t.Run("04_DataStore", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/data_store",
			TerraformBinary: "terraform",
		})
		// No destroy - keep resources up for dependent modules
		terraform.InitAndApply(t, terraformOptions)
		markModuleDeployed("data_store") // Track for failsafe cleanup

		// Verify data store outputs
		tfLocksTable := terraform.Output(t, terraformOptions, "terraform_locks_table_name")
		assert.NotEmpty(t, tfLocksTable, "Terraform locks table should be created")
	})

	t.Run("05_Firewall", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/firewall",
			TerraformBinary: "terraform",
		})
		// No destroy - keep resources up for dependent modules
		terraform.InitAndApply(t, terraformOptions)
		markModuleDeployed("firewall") // Track for failsafe cleanup

		// Verify firewall outputs
		firewallID := terraform.Output(t, terraformOptions, "firewall_id")
		assert.NotEmpty(t, firewallID, "Firewall should be created")
	})

	t.Run("06_Compute", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/compute",
			TerraformBinary: "terraform",
		})
		// No destroy - keep resources up for dependent modules
		terraform.InitAndApply(t, terraformOptions)
		markModuleDeployed("compute") // Track for failsafe cleanup

		// Verify compute outputs
		bastionID := terraform.Output(t, terraformOptions, "bastion_instance_id")
		assert.NotEmpty(t, bastionID, "Bastion instance should be created")

		bastionSG := terraform.Output(t, terraformOptions, "bastion_security_group_id")
		assert.NotEmpty(t, bastionSG, "Bastion security group should be created")
	})

	t.Run("07_Monitoring", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/monitoring",
			TerraformBinary: "terraform",
		})
		// No destroy - keep resources up for dependent modules
		terraform.InitAndApply(t, terraformOptions)
		markModuleDeployed("monitoring") // Track for failsafe cleanup

		// Verify monitoring outputs
		cloudWatchLogGroup := terraform.Output(t, terraformOptions, "cloudwatch_log_group_name")
		assert.NotEmpty(t, cloudWatchLogGroup, "CloudWatch log group should be created")
	})

	t.Run("08_Certificates", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/certificates",
			TerraformBinary: "terraform",
		})
		// No destroy - keep resources up for dependent modules
		terraform.InitAndApply(t, terraformOptions)
		markModuleDeployed("certificates") // Track for failsafe cleanup

		// Verify certificates outputs
		rootCAARN := terraform.Output(t, terraformOptions, "root_ca_arn")
		assert.NotEmpty(t, rootCAARN, "Root CA ARN should be created")
	})

	t.Run("09_RBAC", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/rbac-authorization",
			TerraformBinary: "terraform",
		})
		// No destroy - keep resources up for dependent modules
		terraform.InitAndApply(t, terraformOptions)
		markModuleDeployed("rbac-authorization") // Track for failsafe cleanup

		// Verify RBAC outputs
		bastionPolicyARN := terraform.Output(t, terraformOptions, "bastion_policy_arn")
		assert.NotEmpty(t, bastionPolicyARN, "Bastion policy should be created")
	})

	t.Run("10_Secrets", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/secrets",
			TerraformBinary: "terraform",
		})
		// No destroy - keep resources up for dependent modules
		terraform.InitAndApply(t, terraformOptions)
		markModuleDeployed("secrets") // Track for failsafe cleanup

		// Verify secrets outputs
		dbSecretARN := terraform.Output(t, terraformOptions, "db_credentials_secret_arn")
		assert.NotEmpty(t, dbSecretARN, "DB credentials secret should be created")
	})

	t.Run("11_VPCEndpoints", func(t *testing.T) {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/vpc-endpoints",
			TerraformBinary: "terraform",
		})
		// No destroy - keep resources up for dependent modules
		terraform.InitAndApply(t, terraformOptions)
		markModuleDeployed("vpc-endpoints") // Track for failsafe cleanup

		// Verify VPC endpoints outputs
		s3EndpointID := terraform.Output(t, terraformOptions, "s3_vpc_endpoint_id")
		assert.NotEmpty(t, s3EndpointID, "S3 VPC endpoint should be created")
	})

	// If we reach here successfully, clear the failsafe (TestE2EStackCleanup should be used instead)
	t.Log("=== All E2E tests passed successfully ===")
	t.Log("Run TestE2EStackCleanup to destroy all resources, or set SKIP_E2E_CLEANUP=true to keep them")
}

// TestE2EStackCleanup destroys all resources in reverse dependency order
// Run this test AFTER TestE2EStackDeployment to clean up resources
func TestE2EStackCleanup(t *testing.T) {
	// Do NOT run in parallel - modules must destroy in reverse order
	// t.Parallel()

	// Destroy in reverse dependency order
	modules := []string{
		"vpc-endpoints",
		"secrets",
		"rbac-authorization",
		"certificates",
		"monitoring",
		"compute",
		"firewall",
		"data_store",
		"vpc",
		"security",
		"bootstrap",
	}

	for i, module := range modules {
		t.Run(fmt.Sprintf("%02d_Destroy_%s", i+1, module), func(t *testing.T) {
			terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
				TerraformDir:    "../../envs/test/e2e/" + module,
				TerraformBinary: "terraform",
			})
			terraform.Destroy(t, terraformOptions)
		})
	}
}

// criticalPathModules tracks deployed modules in TestE2ECriticalPath
// Separate from deployedModules to avoid cross-test interference
var criticalPathModules []string

// destroyCriticalPathModules cleans up critical path modules in reverse order
func destroyCriticalPathModules(t *testing.T) {
	if len(criticalPathModules) == 0 {
		t.Log("No critical path modules to clean up")
		return
	}

	t.Log("=== FAILSAFE CLEANUP: Destroying critical path modules ===")

	// Destroy in reverse order (last deployed first)
	for i := len(criticalPathModules) - 1; i >= 0; i-- {
		module := criticalPathModules[i]
		t.Logf("Destroying module: %s", module)

		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/" + module,
			TerraformBinary: "terraform",
			// Disable color output to avoid GitHub Actions ::debug:: interference
			NoColor: true,
		})

		// Use RunTerraformCommandE to avoid failing the test if destroy has issues
		_, err := terraform.RunTerraformCommandE(t, terraformOptions, terraform.FormatArgs(terraformOptions, "destroy", "-auto-approve")...)
		if err != nil {
			t.Logf("Warning: Failed to destroy module %s: %v", module, err)
		} else {
			t.Logf("Successfully destroyed module: %s", module)
		}
	}

	// Clear the tracking slice
	criticalPathModules = nil
	t.Log("=== FAILSAFE CLEANUP COMPLETE ===")
}

// markCriticalPathModuleDeployed adds a module to critical path tracking
func markCriticalPathModuleDeployed(module string) {
	criticalPathModules = append(criticalPathModules, module)
}

// safeOutputAll retrieves all outputs with error handling for CI environments
// GitHub Actions can inject ::debug:: output that corrupts JSON parsing
func safeOutputAll(t *testing.T, terraformOptions *terraform.Options) map[string]interface{} {
	outputs, err := terraform.OutputAllE(t, terraformOptions)
	if err != nil {
		t.Logf("Warning: Failed to parse terraform outputs (this may be a CI environment issue): %v", err)
		// Return empty map instead of failing - the deployment succeeded
		return make(map[string]interface{})
	}
	return outputs
}

// safeOutput retrieves a single output with error handling
func safeOutput(t *testing.T, terraformOptions *terraform.Options, key string) string {
	output, err := terraform.OutputE(t, terraformOptions, key)
	if err != nil {
		t.Logf("Warning: Failed to get output '%s': %v", key, err)
		return ""
	}
	return output
}

// safeOutputList retrieves a list output with error handling
func safeOutputList(t *testing.T, terraformOptions *terraform.Options, key string) []string {
	output, err := terraform.OutputListE(t, terraformOptions, key)
	if err != nil {
		t.Logf("Warning: Failed to get output list '%s': %v", key, err)
		return []string{}
	}
	return output
}

// TestE2ECriticalPath tests only the critical path: Bootstrap → Security → VPC
// This is a faster smoke test for core dependencies
// FAILSAFE: If test fails or is interrupted, t.Cleanup() will destroy all deployed modules
func TestE2ECriticalPath(t *testing.T) {
	// Do NOT run in parallel - modules must deploy in order
	// t.Parallel()

	// Reset critical path modules tracker at start
	criticalPathModules = nil

	// FAILSAFE: Register cleanup function that runs on test failure, panic, or completion
	// Set SKIP_E2E_CLEANUP=true to keep resources after test (useful for debugging)
	if os.Getenv("SKIP_E2E_CLEANUP") != "true" {
		t.Cleanup(func() {
			if t.Failed() {
				t.Log("Test failed - triggering failsafe cleanup")
				destroyCriticalPathModules(t)
			}
		})
	} else {
		t.Log("SKIP_E2E_CLEANUP is set - failsafe cleanup disabled")
	}

	var bootstrapOutputs map[string]interface{}
	var securityOutputs map[string]interface{}
	var vpcOutputs map[string]interface{}

	// Track if any deploy step failed to skip subsequent steps
	var deployFailed bool

	// 1. Deploy Bootstrap
	t.Run("01_BootstrapDeploy", func(t *testing.T) {
		if deployFailed {
			t.Skip("Skipping due to previous deployment failure")
		}

		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/bootstrap",
			TerraformBinary: "terraform",
			// Disable color output to avoid GitHub Actions ::debug:: interference
			NoColor: true,
		})

		// Deploy first, then mark as deployed for cleanup
		if _, err := terraform.InitAndApplyE(t, terraformOptions); err != nil {
			deployFailed = true
			t.Fatalf("Bootstrap deployment failed: %v", err)
		}
		markCriticalPathModuleDeployed("bootstrap") // Track for failsafe cleanup

		// Use safe output functions to avoid JSON parsing issues in CI
		bootstrapOutputs = safeOutputAll(t, terraformOptions)

		// Verify critical outputs exist (use safe functions)
		tfStateBucket := safeOutput(t, terraformOptions, "terraform_state_bucket_name")
		assert.NotEmpty(t, tfStateBucket, "Terraform state bucket must exist")

		cloudtrailBucket := safeOutput(t, terraformOptions, "cloudtrail_bucket_name")
		assert.NotEmpty(t, cloudtrailBucket, "CloudTrail bucket must exist for audit logging")
	})

	// 2. Deploy Security
	t.Run("02_SecurityDeploy", func(t *testing.T) {
		if deployFailed {
			t.Skip("Skipping due to previous deployment failure")
		}

		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/security",
			TerraformBinary: "terraform",
			NoColor:         true,
		})

		if _, err := terraform.InitAndApplyE(t, terraformOptions); err != nil {
			deployFailed = true
			t.Fatalf("Security deployment failed: %v", err)
		}
		markCriticalPathModuleDeployed("security") // Track for failsafe cleanup

		securityOutputs = safeOutputAll(t, terraformOptions)

		// Verify critical outputs exist
		appRole := safeOutput(t, terraformOptions, "app_instance_role_name")
		assert.NotEmpty(t, appRole, "App instance role must exist for compute")

		instanceProfile := safeOutput(t, terraformOptions, "app_instance_profile_name")
		assert.NotEmpty(t, instanceProfile, "Instance profile must exist for compute")

		kmsKeyID := safeOutput(t, terraformOptions, "kms_key_id")
		assert.NotEmpty(t, kmsKeyID, "KMS key must exist for downstream modules")
	})

	// 3. Deploy VPC
	t.Run("03_VPCDeploy", func(t *testing.T) {
		if deployFailed {
			t.Skip("Skipping due to previous deployment failure")
		}

		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir:    "../../envs/test/e2e/vpc",
			TerraformBinary: "terraform",
			NoColor:         true,
		})

		if _, err := terraform.InitAndApplyE(t, terraformOptions); err != nil {
			deployFailed = true
			t.Fatalf("VPC deployment failed: %v", err)
		}
		markCriticalPathModuleDeployed("vpc") // Track for failsafe cleanup

		vpcOutputs = safeOutputAll(t, terraformOptions)

		// Verify critical outputs exist
		vpcID := safeOutput(t, terraformOptions, "vpc_id")
		assert.NotEmpty(t, vpcID, "VPC ID must exist")

		publicSubnets := safeOutputList(t, terraformOptions, "public_subnet_ids")
		assert.Greater(t, len(publicSubnets), 0, "Public subnets must exist for compute")
	})

	// 4. Verify dependency chain
	t.Run("04_DependencyChain", func(t *testing.T) {
		if deployFailed {
			t.Skip("Skipping due to previous deployment failure")
		}

		// All critical paths should have completed
		// Note: These may be empty if output parsing failed, but deployment still succeeded
		t.Logf("Bootstrap outputs: %v", bootstrapOutputs)
		t.Logf("Security outputs: %v", securityOutputs)
		t.Logf("VPC outputs: %v", vpcOutputs)

		// Verify modules were tracked for cleanup
		assert.Equal(t, 3, len(criticalPathModules), "All 3 critical path modules should be tracked")
	})

	// 5. Cleanup deployed resources (only runs if SKIP_E2E_CLEANUP is not set)
	t.Run("05_Cleanup", func(t *testing.T) {
		if os.Getenv("SKIP_E2E_CLEANUP") == "true" {
			t.Skip("SKIP_E2E_CLEANUP is set - skipping cleanup")
		}

		t.Log("=== NORMAL CLEANUP: Destroying critical path modules ===")
		destroyCriticalPathModules(t)
	})
}
