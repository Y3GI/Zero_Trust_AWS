package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestRBACModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/rbac-authorization",
		TerraformBinary: "terraform",
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify IAM policies created
	bastionPolicyARN := terraform.Output(t, terraformOptions, "bastion_policy_arn")
	assert.NotEmpty(t, bastionPolicyARN, "Bastion policy ARN should not be empty")

	appServerPolicyARN := terraform.Output(t, terraformOptions, "app_server_policy_arn")
	assert.NotEmpty(t, appServerPolicyARN, "App server policy ARN should not be empty")
}

func TestRBACPolicies(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/rbac-authorization",
		TerraformBinary: "terraform",
	})

	terraform.InitAndPlan(t, terraformOptions)
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify IAM policies in plan
	assert.Contains(t, plan.ResourceChangesMap, "aws_iam_policy.bastion_policy", "Bastion policy should be in plan")
	assert.Contains(t, plan.ResourceChangesMap, "aws_iam_policy.app_server_policy", "App server policy should be in plan")
}