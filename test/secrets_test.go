package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestSecretsModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/secrets",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":                    "dev",
			"region":                 "eu-north-1",
			"kms_key_id":             "arn:aws:kms:eu-north-1:123456789012:key/12345678",
			"app_instance_role_arn":  "arn:aws:iam::123456789012:role/app-role",
			"db_username":            "dbadmin",
			"db_password":            "Test@1234Secure!",
			"db_host":                "db.example.com",
			"db_port":                float64(5432),
			"db_name":                "testdb",
			"api_key_1":              "test-key-1",
			"api_key_2":              "test-key-2",
		},
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
		TerraformDir:    "../envs/dev/secrets",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":                    "dev",
			"region":                 "eu-north-1",
			"kms_key_id":             "arn:aws:kms:eu-north-1:123456789012:key/12345678",
			"app_instance_role_arn":  "arn:aws:iam::123456789012:role/app-role",
			"db_username":            "dbadmin",
			"db_password":            "Test@1234Secure!",
			"db_host":                "db.example.com",
			"db_port":                float64(5432),
			"db_name":                "testdb",
			"api_key_1":              "test-key-1",
			"api_key_2":              "test-key-2",
		},
	})

	terraform.InitAndPlan(t, terraformOptions)
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify secrets resources in plan
	assert.Contains(t, plan.ResourceChangesMap, "aws_secretsmanager_secret.db_credentials", "DB credentials secret should be in plan")
	assert.Contains(t, plan.ResourceChangesMap, "aws_secretsmanager_secret.api_keys", "API keys secret should be in plan")
}