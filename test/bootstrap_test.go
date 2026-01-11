package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestBootstrapModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/bootstrap",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":        "dev",
			"region":     "eu-north-1",
			"kms_key_id": "arn:aws:kms:eu-north-1:123456789012:key/12345678-1234-1234-1234-123456789012",
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify Terraform state bucket created
	tfStateBucket := terraform.Output(t, terraformOptions, "terraform_state_bucket_name")
	assert.NotEmpty(t, tfStateBucket, "Terraform state bucket name should not be empty")

	// Verify CloudTrail bucket created
	cloudTrailBucket := terraform.Output(t, terraformOptions, "cloudtrail_bucket_name")
	assert.NotEmpty(t, cloudTrailBucket, "CloudTrail bucket name should not be empty")

	// Verify KMS key created
	kmsKeyID := terraform.Output(t, terraformOptions, "kms_key_id")
	assert.NotEmpty(t, kmsKeyID, "KMS key ID should not be empty")
}