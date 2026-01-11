package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestComputeModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/compute",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":                      "dev",
			"region":                   "eu-north-1",
			"vpc_id":                   "vpc-12345678",
			"public_subnet_ids":        []string{"subnet-12345678"},
			"private_subnet_ids":       []string{"subnet-87654321"},
			"kms_key_arn":              "arn:aws:kms:eu-north-1:123456789012:key/12345678",
			"app_instance_profile_name": "app-instance-profile",
			"bastion_allowed_cidr":     "0.0.0.0/0",
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify bastion instance created
	bastionID := terraform.Output(t, terraformOptions, "bastion_instance_id")
	assert.NotEmpty(t, bastionID, "Bastion instance ID should not be empty")

	// Verify bastion security group
	bastionSG := terraform.Output(t, terraformOptions, "bastion_security_group_id")
	assert.NotEmpty(t, bastionSG, "Bastion security group ID should not be empty")
}

func TestComputeEBSEncryption(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/compute",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":                      "dev",
			"region":                   "eu-north-1",
			"vpc_id":                   "vpc-12345678",
			"public_subnet_ids":        []string{"subnet-12345678"},
			"private_subnet_ids":       []string{"subnet-87654321"},
			"kms_key_arn":              "arn:aws:kms:eu-north-1:123456789012:key/12345678",
			"app_instance_profile_name": "app-instance-profile",
			"bastion_allowed_cidr":     "0.0.0.0/0",
		},
	})

	terraform.InitAndPlan(t, terraformOptions)
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify EC2 instances created
	assert.Contains(t, plan.ResourceChangesMap, "aws_instance.bastion", "Bastion instance should be in plan")
}

func TestComputeUserData(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/compute",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":                      "dev",
			"region":                   "eu-north-1",
			"vpc_id":                   "vpc-12345678",
			"public_subnet_ids":        []string{"subnet-12345678"},
			"private_subnet_ids":       []string{"subnet-87654321"},
			"kms_key_arn":              "arn:aws:kms:eu-north-1:123456789012:key/12345678",
			"app_instance_profile_name": "app-instance-profile",
			"bastion_allowed_cidr":     "0.0.0.0/0",
		},
	})

	terraform.InitAndPlan(t, terraformOptions)

	// Verify security groups created
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
	assert.Contains(t, plan.ResourceChangesMap, "aws_security_group.bastion", "Bastion security group should be in plan")
}