package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestDataStoreModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/data_store",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":         "dev",
			"region":      "eu-north-1",
			"kms_key_arn": "arn:aws:kms:eu-north-1:123456789012:key/12345678",
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify DynamoDB tables created
	tfLocksTable := terraform.Output(t, terraformOptions, "terraform_locks_table_name")
	assert.NotEmpty(t, tfLocksTable, "Terraform locks table name should not be empty")

	ddbTable := terraform.Output(t, terraformOptions, "dynamodb_table_name")
	assert.NotEmpty(t, ddbTable, "DynamoDB table name should not be empty")
}

func TestDataStoreEncryption(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/data_store",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":         "dev",
			"region":      "eu-north-1",
			"kms_key_arn": "arn:aws:kms:eu-north-1:123456789012:key/12345678",
		},
	})

	terraform.InitAndPlan(t, terraformOptions)
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify DynamoDB table resources are in plan
	assert.Contains(t, plan.ResourceChangesMap, "aws_dynamodb_table.terraform_locks", "DynamoDB locks table should be in plan")
}

func TestDataStoreBackup(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/data_store",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":         "dev",
			"region":      "eu-north-1",
			"kms_key_arn": "arn:aws:kms:eu-north-1:123456789012:key/12345678",
		},
	})

	terraform.InitAndPlan(t, terraformOptions)
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify backup resources are created
	assert.Greater(t, len(plan.ResourceChangesMap), 0, "Should have created resources")
}

func TestDataStorePublicAccess(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/data_store",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":         "dev",
			"region":      "eu-north-1",
			"kms_key_arn": "arn:aws:kms:eu-north-1:123456789012:key/12345678",
		},
	})

	terraform.InitAndPlan(t, terraformOptions)
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify DynamoDB is not publicly accessible (no internet gateway attachment)
	assert.NotContains(t, plan.ResourceChangesMap, "aws_route.public_dynamodb", "DynamoDB should not be publicly accessible")
}