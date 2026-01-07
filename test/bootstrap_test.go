package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestBootstrapModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../envs/dev/bootstrap",
		NoColor:      true,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify S3 bucket was created
	s3BucketName := terraform.Output(t, terraformOptions, "s3_bucket_id")
	assert.NotEmpty(t, s3BucketName, "S3 bucket name should not be empty")
}