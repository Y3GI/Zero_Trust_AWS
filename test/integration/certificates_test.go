package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestCertificatesModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/certificates",
		TerraformBinary: "terraform",
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify root CA created
	rootCAARN := terraform.Output(t, terraformOptions, "root_ca_arn")
	assert.NotEmpty(t, rootCAARN, "Root CA ARN should not be empty")

	// Verify root CA domain
	rootCADomain := terraform.Output(t, terraformOptions, "root_ca_domain")
	assert.NotEmpty(t, rootCADomain, "Root CA domain should not be empty")
}