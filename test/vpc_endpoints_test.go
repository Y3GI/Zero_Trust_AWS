package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestVPCEndpointsModule(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/vpc-endpoints",
        Vars: map[string]interface{}{
            "vpc_id":            "vpc-12345678",
            "private_subnet_ids": []string{"subnet-12345678"},
            "security_group_id": "sg-12345678",
            "environment":       "test",
        },
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndPlan(t, terraformOptions)

    // Verify plan creates expected resources
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Should create 8 interface endpoints + 1 gateway endpoint
    assert.Equal(t, 9, len(planStruct.ResourceChangesMap))
    
    // Verify SSM endpoint
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_vpc_endpoint.ssm")
    
    // Verify S3 gateway endpoint
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_vpc_endpoint.s3")
}

func TestVPCEndpointsOutputs(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/vpc-endpoints",
        Vars: map[string]interface{}{
            "vpc_id":            "vpc-12345678",
            "private_subnet_ids": []string{"subnet-12345678"},
            "security_group_id": "sg-12345678",
            "environment":       "test",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    
    // Verify outputs are defined
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    assert.NotNil(t, planStruct.RawPlan.OutputChanges)
}