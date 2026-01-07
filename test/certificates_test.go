package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestCertificatesModule(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/certificates",
        Vars: map[string]interface{}{
            "domain_name": "*.example.com",
            "environment": "test",
        },
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndPlan(t, terraformOptions)

    planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)
    
    // Verify ACM certificate created
    assert.Contains(t, planStruct.ResourceChangesMap, "aws_acm_certificate.main")
    
    // Verify DNS validation method
    certResource := planStruct.ResourceChangesMap["aws_acm_certificate.main"]
    assert.NotNil(t, certResource)
    
    after := certResource.Change.After.(map[string]interface{})
    assert.Equal(t, "DNS", after["validation_method"])
    assert.Equal(t, "*.example.com", after["domain_name"])
}