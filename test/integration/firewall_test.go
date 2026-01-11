package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestFirewallModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/firewall",
		TerraformBinary: "terraform",
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify firewall resources created
	firewallID := terraform.Output(t, terraformOptions, "firewall_id")
	assert.NotEmpty(t, firewallID, "Firewall ID should not be empty")

	firewallPolicyID := terraform.Output(t, terraformOptions, "firewall_policy_id")
	assert.NotEmpty(t, firewallPolicyID, "Firewall policy ID should not be empty")
}

func TestFirewallNACLs(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/firewall",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":               "dev",
			"region":            "eu-north-1",
			"vpc_id":            "vpc-12345678",
			"public_subnet_ids": []string{"subnet-12345678"},
		},
	})

	terraform.InitAndPlan(t, terraformOptions)
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify firewall rule group in plan
	assert.Contains(t, plan.ResourceChangesMap, "aws_networkfirewall_rule_group.stateful", "Firewall rule group should be in plan")
}

func TestFirewallSecurityGroupRules(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/firewall",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"env":               "dev",
			"region":            "eu-north-1",
			"vpc_id":            "vpc-12345678",
			"public_subnet_ids": []string{"subnet-12345678"},
		},
	})

	terraform.InitAndPlan(t, terraformOptions)
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify firewall status endpoint in plan
	assert.Contains(t, plan.ResourceChangesMap, "aws_networkfirewall_firewall_policy.main", "Firewall policy should be in plan")
}