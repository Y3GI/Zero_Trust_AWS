package integration

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestSecretsModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../../envs/test/integration/secrets",
		TerraformBinary: "terraform",
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify DB credentials secret created
	dbSecretARN := terraform.Output(t, terraformOptions, "db_credentials_secret_arn")
	assert.NotEmpty(t, dbSecretARN, "DB credentials secret ARN should not be empty")

	// Verify API keys secret created
	apiSecretARN := terraform.Output(t, terraformOptions, "api_keys_secret_arn")
	assert.NotEmpty(t, apiSecretARN, "API keys secret ARN should not be empty")
}

func TestSecretsPasswordComplexity(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../../envs/test/integration/secrets",
		TerraformBinary: "terraform",
	})

	terraform.InitAndPlan(t, terraformOptions)
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify secrets resources in plan
	assert.Contains(t, plan.ResourceChangesMap, "aws_secretsmanager_secret.db_credentials", "DB credentials secret should be in plan")
	assert.Contains(t, plan.ResourceChangesMap, "aws_secretsmanager_secret.api_keys", "API keys secret should be in plan")
}
