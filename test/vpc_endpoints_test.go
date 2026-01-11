package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVPCEndpointsModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/vpc-endpoints",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":                    "dev",
			"region":                 "eu-north-1",
			"vpc_id":                 "vpc-12345678",
			"vpc_cidr":               "10.0.0.0/16",
			"private_subnet_ids":     []string{"subnet-12345678"},
			"private_rt_id":          "rtb-12345678",
			"public_rt_id":           "rtb-87654321",
			"cloudtrail_bucket_name": "cloudtrail-bucket",
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify S3 VPC endpoint created
	s3EndpointID := terraform.Output(t, terraformOptions, "s3_vpc_endpoint_id")
	assert.NotEmpty(t, s3EndpointID, "S3 VPC endpoint ID should not be empty")

	// Verify Secrets Manager VPC endpoint created
	secretsEndpointID := terraform.Output(t, terraformOptions, "secretsmanager_vpc_endpoint_id")
	assert.NotEmpty(t, secretsEndpointID, "Secrets Manager VPC endpoint ID should not be empty")
}

func TestVPCEndpointsOutputs(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/vpc-endpoints",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":                    "dev",
			"region":                 "eu-north-1",
			"vpc_id":                 "vpc-12345678",
			"vpc_cidr":               "10.0.0.0/16",
			"private_subnet_ids":     []string{"subnet-12345678"},
			"private_rt_id":          "rtb-12345678",
			"public_rt_id":           "rtb-87654321",
			"cloudtrail_bucket_name": "cloudtrail-bucket",
		},
	})

	terraform.InitAndPlan(t, terraformOptions)
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify VPC endpoint resources in plan
	assert.Contains(t, plan.ResourceChangesMap, "aws_vpc_endpoint.s3", "S3 VPC endpoint should be in plan")
	assert.Contains(t, plan.ResourceChangesMap, "aws_vpc_endpoint.secretsmanager", "Secrets Manager VPC endpoint should be in plan")
}