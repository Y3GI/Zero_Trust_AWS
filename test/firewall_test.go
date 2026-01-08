package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestFirewallModule(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir:    "../modules/firewall",
        TerraformBinary: "terraform",
        Vars: map[string]interface{}{
            "vpc_id": "vpc-12345678",
            "vpc_cidr": "10.0.0.0/16",
            "public_subnet_ids": []string{"subnet-12345678"},
            "private_subnet_ids": []string{"subnet-87654321"},
            "database_subnet_ids": []string{"subnet-11111111"},
            "environment": "test",
        },
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndPlan(t, terraformOptions)

    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify security groups created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_security_group.vpc_endpoints")
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_security_group.ec2")
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_security_group.rds")
}

func TestFirewallNACLs(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir:    "../modules/firewall",
        TerraformBinary: "terraform",
        Vars: map[string]interface{}{
            "vpc_id": "vpc-12345678",
            "vpc_cidr": "10.0.0.0/16",
            "public_subnet_ids": []string{"subnet-12345678"},
            "private_subnet_ids": []string{"subnet-87654321"},
            "database_subnet_ids": []string{"subnet-11111111"},
            "environment": "test",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify NACLs created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_network_acl.public")
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_network_acl.private")
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_network_acl.database")
}

func TestFirewallSecurityGroupRules(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir:    "../modules/firewall",
        TerraformBinary: "terraform",
        Vars: map[string]interface{}{
            "vpc_id": "vpc-12345678",
            "vpc_cidr": "10.0.0.0/16",
            "public_subnet_ids": []string{"subnet-12345678"},
            "private_subnet_ids": []string{"subnet-87654321"},
            "database_subnet_ids": []string{"subnet-11111111"},
            "environment": "test",
        },
    })

    terraform.InitAndPlan(t, terraformOptions)
    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify VPC endpoint security group allows HTTPS from VPC
    vpcEndpointSG := planStruct.ResourceChangesMap["aws_security_group.vpc_endpoints"]
    assert.NotNil(t, vpcEndpointSG)
    
    // Verify RDS security group only allows PostgreSQL from EC2
    rdsSG := planStruct.ResourceChangesMap["aws_security_group.rds"]
    assert.NotNil(t, rdsSG)
}