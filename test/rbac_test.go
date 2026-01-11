package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestRBACModule(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir:    "../modules/rbac-authorization",
        TerraformBinary: "terraform",
        Vars: map[string]interface{}{
            "environment": "test",
        },
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndPlan(t, terraformOptions)

    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify IAM groups created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_iam_group.developers")
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_iam_group.operators")
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_iam_group.auditors")
}

func TestRBACPolicies(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir:    "../modules/rbac-authorization",
        TerraformBinary: "terraform",
        Vars: map[string]interface{}{
            "environment": "test",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify developer policy
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_iam_policy.developer_policy")
    
    // Verify operator policy
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_iam_policy.operator_policy")
    
    // Verify auditor policy
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_iam_policy.auditor_policy")
}