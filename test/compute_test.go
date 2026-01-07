package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestComputeModule(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/compute",
        Vars: map[string]interface{}{
            "subnet_id": "subnet-12345678",
            "security_group_ids": []string{"sg-12345678"},
            "iam_instance_profile": "ec2-instance-profile",
            "kms_key_id": "arn:aws:kms:eu-north-1:123456789012:key/12345678-1234-1234-1234-123456789012",
            "environment": "test",
        },
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndPlan(t, terraformOptions)

    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify EC2 instance created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_instance.main")
    
    ec2Instance := planStruct.ResourceChangesMap["aws_instance.main"]
    assert.NotNil(t, ec2Instance)
    
    after := ec2Instance.Change.After.(map[string]interface{})
    assert.Equal(t, "t3.micro", after["instance_type"])
    assert.Equal(t, false, after["associate_public_ip_address"])
}

func TestComputeEBSEncryption(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/compute",
        Vars: map[string]interface{}{
            "subnet_id": "subnet-12345678",
            "security_group_ids": []string{"sg-12345678"},
            "iam_instance_profile": "ec2-instance-profile",
            "kms_key_id": "arn:aws:kms:eu-north-1:123456789012:key/12345678-1234-1234-1234-123456789012",
            "environment": "test",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify EBS volume is encrypted
    ec2Instance := planStruct.ResourceChangesMap["aws_instance.main"]
    after := ec2Instance.Change.After.(map[string]interface{})
    
    rootBlockDevice := after["root_block_device"].([]interface{})[0].(map[string]interface{})
    assert.Equal(t, true, rootBlockDevice["encrypted"])
}

func TestComputeUserData(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/compute",
        Vars: map[string]interface{}{
            "subnet_id": "subnet-12345678",
            "security_group_ids": []string{"sg-12345678"},
            "iam_instance_profile": "ec2-instance-profile",
            "kms_key_id": "arn:aws:kms:eu-north-1:123456789012:key/12345678-1234-1234-1234-123456789012",
            "environment": "test",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify user data is configured
    ec2Instance := planStruct.ResourceChangesMap["aws_instance.main"]
    after := ec2Instance.Change.After.(map[string]interface{})
    assert.NotEmpty(t, after["user_data"])
}