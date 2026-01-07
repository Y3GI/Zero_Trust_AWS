package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestIntegration(t *testing.T) {
	options := &terraform.Options{
		TerraformDir: "../path/to/your/terraform/code",
	}

	defer terraform.Destroy(t, options)

	initAndApply := terraform.InitAndApply(t, options)

	assert.True(t, initAndApply)
}