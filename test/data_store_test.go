package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestDataStoreModule(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/data_store",
        Vars: map[string]interface{}{
            "subnet_ids": []string{"subnet-12345678", "subnet-87654321"},
            "security_group_id": "sg-12345678",
            "kms_key_id": "arn:aws:kms:eu-north-1:123456789012:key/12345678-1234-1234-1234-123456789012",
            "db_username": "dbadmin",
            "db_password": "TestPassword123!",
            "environment": "test",
        },
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndPlan(t, terraformOptions)

    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify RDS instance created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_db_instance.main")
    
    // Verify subnet group created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_db_subnet_group.main")
}

func TestDataStoreEncryption(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/data_store",
        Vars: map[string]interface{}{
            "subnet_ids": []string{"subnet-12345678", "subnet-87654321"},
            "security_group_id": "sg-12345678",
            "kms_key_id": "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012",
            "db_username": "dbadmin",
            "db_password": "TestPassword123!",
            "environment": "test",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify RDS encryption enabled
    rdsInstance := planStruct.ResourceChangesMap["aws_db_instance.main"]
    assert.NotNil(t, rdsInstance)
    
    after := rdsInstance.Change.After.(map[string]interface{})
    assert.Equal(t, true, after["storage_encrypted"])
}

func TestDataStoreBackup(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/data_store",
        Vars: map[string]interface{}{
            "subnet_ids": []string{"subnet-12345678", "subnet-87654321"},
            "security_group_id": "sg-12345678",
            "kms_key_id": "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012",
            "db_username": "dbadmin",
            "db_password": "TestPassword123!",
            "environment": "test",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify backup retention configured
    rdsInstance := planStruct.ResourceChangesMap["aws_db_instance.main"]
    after := rdsInstance.Change.After.(map[string]interface{})
    assert.GreaterOrEqual(t, after["backup_retention_period"], float64(7))
}

func TestDataStorePublicAccess(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/data_store",
        Vars: map[string]interface{}{
            "subnet_ids": []string{"subnet-12345678", "subnet-87654321"},
            "security_group_id": "sg-12345678",
            "kms_key_id": "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012",
            "db_username": "dbadmin",
            "db_password": "TestPassword123!",
            "environment": "test",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify RDS is not publicly accessible
    rdsInstance := planStruct.ResourceChangesMap["aws_db_instance.main"]
    after := rdsInstance.Change.After.(map[string]interface{})
    assert.Equal(t, false, after["publicly_accessible"])
}