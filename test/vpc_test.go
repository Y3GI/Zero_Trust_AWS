package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVpcCreation(t *testing.T) {
	options := &terraform.Options{
		TerraformDir: "../path/to/your/vpc/module",
	}

	defer terraform.Destroy(t, options)

	initAndApply := terraform.InitAndApply(t, options)

	assert.True(t, initAndApply)
}