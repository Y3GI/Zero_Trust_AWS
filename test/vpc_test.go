package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVpcCreation(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/vpc",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":       "dev",
			"region":    "eu-north-1",
			"vpc_cidr":  "10.0.0.0/16",
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify VPC created
	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcID, "VPC ID should not be empty")

	// Verify CIDR block
	vpcCIDR := terraform.Output(t, terraformOptions, "vpc_cidr")
	assert.Equal(t, "10.0.0.0/16", vpcCIDR, "VPC CIDR should match")

	// Verify public subnets created
	publicSubnets := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	assert.Greater(t, len(publicSubnets), 0, "Should have at least one public subnet")

	// Verify private subnets created
	privateSubnets := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
	assert.Greater(t, len(privateSubnets), 0, "Should have at least one private subnet")

	// Verify Internet Gateway created
	igwID := terraform.Output(t, terraformOptions, "igw_id")
	assert.NotEmpty(t, igwID, "IGW ID should not be empty")

	// Verify NAT Gateway created
	natGatewayID := terraform.Output(t, terraformOptions, "nat_gateway_id")
	assert.NotEmpty(t, natGatewayID, "NAT Gateway ID should not be empty")
}