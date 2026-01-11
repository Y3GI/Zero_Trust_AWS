package integration

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestMonitoringModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/monitoring",
		TerraformBinary: "terraform",
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify CloudWatch log group created
	logGroupName := terraform.Output(t, terraformOptions, "cloudwatch_log_group_name")
	assert.NotEmpty(t, logGroupName, "CloudWatch log group name should not be empty")

	// Verify budget created
	budgetID := terraform.Output(t, terraformOptions, "budget_id")
	assert.NotEmpty(t, budgetID, "Budget ID should not be empty")
}

func TestMonitoringCloudTrail(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/monitoring",
		TerraformBinary: "terraform",
	})

	terraform.InitAndPlan(t, terraformOptions)
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify CloudTrail in plan
	assert.Contains(t, plan.ResourceChangesMap, "aws_cloudtrail.main", "CloudTrail should be in plan")
}

func TestMonitoringAlarms(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/monitoring",
		TerraformBinary: "terraform",
	})

	terraform.InitAndPlan(t, terraformOptions)
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify alarms in plan
	assert.Contains(t, plan.ResourceChangesMap, "aws_cloudwatch_metric_alarm.authorized_api_calls", "CloudWatch alarm should be in plan")
}

func TestMonitoringBudget(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../envs/dev/monitoring",
		TerraformBinary: "terraform",
	})

	terraform.InitAndPlan(t, terraformOptions)
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Verify budget in plan
	assert.Contains(t, plan.ResourceChangesMap, "aws_budgets_budget.monthly", "Budget should be in plan")
}