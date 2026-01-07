package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestSecurityModule(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/security",
        Vars: map[string]interface{}{
            "environment": "test",
            "project_name": "zero-trust",
        },
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndPlan(t, terraformOptions)

    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify IAM role created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_iam_role.ec2_role")
    
    // Verify instance profile created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_iam_instance_profile.ec2_profile")
    
    // Verify KMS key created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_kms_key.main")
    
    // Verify KMS alias created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_kms_alias.main")
}

func TestSecurityKMSRotation(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/security",
        Vars: map[string]interface{}{
            "environment": "test",
            "project_name": "zero-trust",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify KMS key has rotation enabled
    kmsKey := planStruct.ResourceChangesMap["aws_kms_key.main"]
    assert.NotNil(t, kmsKey)
    assert.Equal(t, true, kmsKey.Change.After.(map[string]interface{})["enable_key_rotation"])
}

func TestSecurityIAMPolicies(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/security",
        Vars: map[string]interface{}{
            "environment": "test",
            "project_name": "zero-trust",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify SSM managed policy attachment
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_iam_role_policy_attachment.ssm_policy")
    
    // Verify CloudWatch managed policy attachment
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_iam_role_policy_attachment.cloudwatch_policy")
    
    // Verify Secrets Manager managed policy attachment
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_iam_role_policy_attachment.secrets_policy")
}