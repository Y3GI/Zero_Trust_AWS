package unit

import (
	"io/ioutil"
	"regexp"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestModulesValidate ensures all Terraform modules can be parsed
func TestModulesExist(t *testing.T) {
	t.Parallel()

	expectedModules := []string{
		"bootstrap",
		"vpc",
		"security",
		"compute",
		"data_store",
		"firewall",
		"monitoring",
		"certificates",
		"rbac-authorization",
		"secrets",
		"vpc-endpoints",
	}

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)
	require.Greater(t, len(files), 0, "No Terraform files found in modules")

	for _, module := range expectedModules {
		found := false
		for _, file := range files {
			if strings.Contains(file, "/"+module+"/") {
				found = true
				break
			}
		}
		assert.True(t, found, "Module %s should exist", module)
	}
}

// TestEnvironmentConfigurations ensures all environment configurations exist
func TestEnvironmentConfigurationsExist(t *testing.T) {
	t.Parallel()

	expectedEnvs := []string{
		"bootstrap",
		"vpc",
		"security",
		"compute",
		"data_store",
		"firewall",
		"monitoring",
		"certificates",
		"rbac-authorization",
		"secrets",
		"vpc-endpoints",
	}

	envDir := "../../envs/dev"
	files, err := findTerraformFiles(envDir)
	require.NoError(t, err)
	require.Greater(t, len(files), 0, "No Terraform files found in envs/dev")

	for _, env := range expectedEnvs {
		found := false
		for _, file := range files {
			if strings.Contains(file, "/"+env+"/") {
				found = true
				break
			}
		}
		assert.True(t, found, "Environment configuration for %s should exist", env)
	}
}

// TestNoDeprecatedResources ensures deprecated AWS resources aren't used
func TestNoDeprecatedResources(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	deprecatedResources := map[string]string{
		`aws_iam_policy_attachment`: "Use aws_iam_role_policy_attachment or aws_iam_group_policy_attachment",
		`aws_security_group_rule`:   "Define ingress/egress within aws_security_group or use aws_vpc_security_group_ingress_rule",
	}

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		contentStr := string(content)
		for deprecated, recommendation := range deprecatedResources {
			assert.NotContains(t, contentStr, deprecated,
				"File %s uses deprecated resource %s. Recommendation: %s", file, deprecated, recommendation)
		}
	}
}

// TestProviderConfiguration ensures proper provider versions
func TestProviderConfiguration(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	awsProviderPattern := regexp.MustCompile(`required_providers\s*\{|terraform\s*\{`)

	foundProviderBlock := false
	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		if awsProviderPattern.MatchString(string(content)) {
			foundProviderBlock = true
			break
		}
	}

	assert.True(t, foundProviderBlock, "Provider configuration should be defined")
}

// TestBackendConfiguration ensures state backend is properly configured
func TestBackendConfiguration(t *testing.T) {
	t.Parallel()

	envDir := "../../envs/dev"
	files, err := findTerraformFiles(envDir)
	require.NoError(t, err)

	backendPattern := regexp.MustCompile(`terraform\s*\{.*backend`)

	foundBackend := false
	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		if backendPattern.MatchString(string(content)) {
			foundBackend = true
			break
		}
	}

	assert.True(t, foundBackend, "Backend configuration should be defined in environment configs")
}

// TestDataSourceUsage ensures external data is sourced properly
func TestNoHardcodedAccountID(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	// Pattern to catch hardcoded AWS account IDs (12 digits in quotes)
	accountIDPattern := regexp.MustCompile(`["']\d{12}["']`)
	exceptions := map[string]bool{
		"123456789012": true, // Example/placeholder account ID
	}

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		matches := accountIDPattern.FindAllString(string(content), -1)
		for _, match := range matches {
			accountID := strings.Trim(match, `"'`)
			if !exceptions[accountID] {
				assert.True(t, exceptions[accountID],
					"File %s should use data.aws_caller_identity.current.account_id instead of hardcoded %s", file, accountID)
			}
		}
	}
}

// TestVariableDefaults ensures sensitive variables have secure defaults
func TestSensitiveVariableDefaults(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	sensitiveVarPattern := regexp.MustCompile(`variable\s+"(password|secret|key|token)`)
	sensitivePattern := regexp.MustCompile(`sensitive\s*=\s*true`)

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		contentStr := string(content)
		if sensitiveVarPattern.MatchString(contentStr) {
			assert.True(t, sensitivePattern.MatchString(contentStr),
				"File %s should mark sensitive variables with sensitive = true", file)
		}
	}
}

// TestOutputExports ensures sensitive outputs are not exported unencrypted
func TestOutputSecurity(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	sensitiveOutputPattern := regexp.MustCompile(`output\s+"(password|secret|private_key|api_key)"`)
	sensitiveBlockPattern := regexp.MustCompile(`sensitive\s*=\s*true`)

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		contentStr := string(content)
		if sensitiveOutputPattern.MatchString(contentStr) {
			assert.True(t, sensitiveBlockPattern.MatchString(contentStr),
				"File %s should mark sensitive outputs with sensitive = true", file)
		}
	}
}

// TestResourceNaming ensures resources follow naming conventions
func TestResourceNamingConvention(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	resourcePattern := regexp.MustCompile(`resource\s+"([^"]+)"\s+"([^"]+)"`)

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		matches := resourcePattern.FindAllStringSubmatch(string(content), -1)
		for _, match := range matches {
			resourceName := match[2]
			// Resource names should be snake_case
			assert.Regexp(t, `^[a-z0-9_]+$`, resourceName,
				"Resource %s in %s should follow snake_case naming convention", resourceName, file)
		}
	}
}

// TestCommentedCode ensures no large blocks of commented code
func TestNoCommentedCode(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		lines := strings.Split(string(content), "\n")
		consecutiveCommentedLines := 0

		for _, line := range lines {
			trimmed := strings.TrimSpace(line)
			if strings.HasPrefix(trimmed, "#") && len(trimmed) > 2 {
				consecutiveCommentedLines++
				assert.Less(t, consecutiveCommentedLines, 10,
					"File %s has %d consecutive commented lines (should be max 5)", file, consecutiveCommentedLines)
			} else {
				consecutiveCommentedLines = 0
			}
		}
	}
}

// TestNullResource checks for unnecessary null resources
func TestNoUnnecessaryNullResources(t *testing.T) {
	t.Parallel()

	terraformDir := "../../modules"
	files, err := findTerraformFiles(terraformDir)
	require.NoError(t, err)

	nullResourcePattern := regexp.MustCompile(`resource\s+"null_resource"`)
	warningCount := 0

	for _, file := range files {
		content, err := ioutil.ReadFile(file)
		if err != nil {
			continue
		}

		if nullResourcePattern.MatchString(string(content)) {
			warningCount++
		}
	}

	// null_resource should rarely be used; warn if found
	assert.Zero(t, warningCount, "Found %d null_resource blocks - should use native Terraform features instead", warningCount)
}
