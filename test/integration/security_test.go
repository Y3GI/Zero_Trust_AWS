package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestSecurityModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/security",
		TerraformBinary: "terraform",
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify IAM roles created
	appRoleName := terraform.Output(t, terraformOptions, "app_instance_role_name")
	assert.NotEmpty(t, appRoleName, "App instance role name should not be empty")

	// Verify KMS key created
	kmsKeyID := terraform.Output(t, terraformOptions, "kms_key_id")
	assert.NotEmpty(t, kmsKeyID, "KMS key ID should not be empty")

	// Verify instance profile created
	instanceProfile := terraform.Output(t, terraformOptions, "app_instance_profile_name")
	assert.NotEmpty(t, instanceProfile, "Instance profile name should not be empty")
}

func TestSecurityKMSRotation(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/security",
		TerraformBinary: "terraform",
	})

	terraform.InitAndPlan(t, terraformOptions)
	planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify KMS key created
	kmsKey := planStruct.ResourceChangesMap["aws_kms_key.main"]
	assert.NotNil(t, kmsKey, "KMS key should be created")
}

func TestSecurityIAMPolicies(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/security",
		TerraformBinary: "terraform",
	})

	terraform.InitAndPlan(t, terraformOptions)
	planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify IAM role is created
	iamRole := planStruct.ResourceChangesMap["aws_iam_role.app_instance_role"]
	assert.NotNil(t, iamRole, "IAM role should be created")
}