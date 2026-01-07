package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestMonitoringModule(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/monitoring",
        Vars: map[string]interface{}{
            "environment": "test",
            "kms_key_id": "arn:aws:kms:eu-north-1:123456789012:key/12345678-1234-1234-1234-123456789012",
        },
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndPlan(t, terraformOptions)

    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify CloudTrail created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_cloudtrail.main")
    
    // Verify CloudWatch log groups
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_cloudwatch_log_group.ec2")
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_cloudwatch_log_group.rds")
    
    // Verify SNS topics
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_sns_topic.security_alerts")
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_sns_topic.monitoring_alerts")
}

func TestMonitoringCloudTrail(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/monitoring",
        Vars: map[string]interface{}{
            "environment": "test",
            "kms_key_id": "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify CloudTrail multi-region enabled
    trail := planStruct.ResourceChangesMap["aws_cloudtrail.main"]
    assert.NotNil(t, trail)
    
    after := trail.Change.After.(map[string]interface{})
    assert.Equal(t, true, after["is_multi_region_trail"])
    assert.Equal(t, true, after["enable_log_file_validation"])
}

func TestMonitoringAlarms(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/monitoring",
        Vars: map[string]interface{}{
            "environment": "test",
            "kms_key_id": "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify alarms created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_cloudwatch_metric_alarm.unauthorized_api_calls")
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_cloudwatch_metric_alarm.ec2_high_cpu")
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_cloudwatch_metric_alarm.rds_high_cpu")
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_cloudwatch_metric_alarm.rds_low_storage")
}

func TestMonitoringBudget(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/monitoring",
        Vars: map[string]interface{}{
            "environment": "test",
            "kms_key_id": "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify budget created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_budgets_budget.monthly")
}