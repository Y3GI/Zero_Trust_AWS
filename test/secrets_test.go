package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestSecretsModule(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/secrets",
        Vars: map[string]interface{}{
            "environment": "test",
            "kms_key_id": "arn:aws:kms:eu-north-1:123456789012:key/12345678-1234-1234-1234-123456789012",
        },
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndPlan(t, terraformOptions)

    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify RDS secret created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_secretsmanager_secret.rds_credentials")
    
    // Verify secret version with random password
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_secretsmanager_secret_version.rds_credentials")
    
    // Verify random password resource
    assert.Contains(t, planStruct.ResourceChangesMap, "random_password.rds_password")
}

func TestSecretsPasswordComplexity(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/secrets",
        Vars: map[string]interface{}{
            "environment": "test",
            "kms_key_id": "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify password meets complexity requirements
    passwordResource := planStruct.ResourceChangesMap["random_password.rds_password"]
    assert.NotNil(t, passwordResource)
    
    after := passwordResource.Change.After.(map[string]interface{})
    assert.Equal(t, float64(32), after["length"])
    assert.Equal(t, true, after["special"])
}