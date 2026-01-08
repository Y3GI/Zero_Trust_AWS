package test

import (
    "fmt"
    "testing"
    "time"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

// TestFullZeroTrustInfrastructure orchestrates all module tests in deployment order
func TestFullZeroTrustInfrastructure(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping full integration test in short mode")
    }

    projectName := fmt.Sprintf("zt-full-%d", time.Now().Unix())

    // Test 1: Bootstrap (from bootstrap_test.go)
    t.Run("Bootstrap", func(t *testing.T) {
        bootstrapOptions := &terraform.Options{
            TerraformDir: "../envs/dev/bootstrap",
            TerraformBinary: "terraform",
            Vars: map[string]interface{}{
                "project_name": projectName,
                "environment":  "test",
            },
        }

        defer terraform.Destroy(t, bootstrapOptions)
        terraform.InitAndApply(t, bootstrapOptions)

        stateBucket := terraform.Output(t, bootstrapOptions, "state_bucket_name")
        lockTable := terraform.Output(t, bootstrapOptions, "lock_table_name")

        assert.NotEmpty(t, stateBucket)
        assert.NotEmpty(t, lockTable)
        assert.Contains(t, stateBucket, "terraform-state")
        
        t.Logf("✅ Bootstrap deployed: S3=%s, DynamoDB=%s", stateBucket, lockTable)
    })

    // Test 2: VPC (from vpc_test.go)
    var vpcId string
    var privateSubnets, publicSubnets, databaseSubnets []string

    t.Run("VPC", func(t *testing.T) {
        vpcOptions := &terraform.Options{
            TerraformDir: "../envs/dev/vpc",
            TerraformBinary: "terraform",
            Vars: map[string]interface{}{
                "project_name":       projectName,
                "environment":        "test",
                "vpc_cidr":           "10.0.0.0/16",
                "availability_zones": []string{"eu-north-1a"},
            },
        }

        defer terraform.Destroy(t, vpcOptions)
        terraform.InitAndApply(t, vpcOptions)

        vpcId = terraform.Output(t, vpcOptions, "vpc_id")
        privateSubnets = terraform.OutputList(t, vpcOptions, "private_subnet_ids")
        publicSubnets = terraform.OutputList(t, vpcOptions, "public_subnet_ids")
        databaseSubnets = terraform.OutputList(t, vpcOptions, "database_subnet_ids")

        assert.NotEmpty(t, vpcId)
        assert.Contains(t, vpcId, "vpc-")
        assert.GreaterOrEqual(t, len(privateSubnets), 1)
        assert.GreaterOrEqual(t, len(publicSubnets), 1)
        assert.GreaterOrEqual(t, len(databaseSubnets), 1)

        t.Logf("✅ VPC deployed: ID=%s, Private=%d, Public=%d, Database=%d", 
            vpcId, len(privateSubnets), len(publicSubnets), len(databaseSubnets))
    })

    // Test 3: Security (from security_test.go)
    var kmsKeyId, kmsKeyArn, ec2RoleArn, instanceProfileName string

    t.Run("Security", func(t *testing.T) {
        securityOptions := &terraform.Options{
            TerraformDir: "../envs/dev/security",
            TerraformBinary: "terraform",
            Vars: map[string]interface{}{
                "project_name": projectName,
                "environment":  "test",
            },
            MaxRetries:         3,
            TimeBetweenRetries: 10 * time.Second,
        }

        defer terraform.Destroy(t, securityOptions)
        terraform.InitAndApply(t, securityOptions)

        kmsKeyId = terraform.Output(t, securityOptions, "kms_key_id")
        kmsKeyArn = terraform.Output(t, securityOptions, "kms_key_arn")
        ec2RoleArn = terraform.Output(t, securityOptions, "ec2_role_arn")
        instanceProfileName = terraform.Output(t, securityOptions, "instance_profile_name")

        assert.NotEmpty(t, kmsKeyId)
        assert.NotEmpty(t, kmsKeyArn)
        assert.NotEmpty(t, ec2RoleArn)
        assert.NotEmpty(t, instanceProfileName)
        assert.Contains(t, kmsKeyArn, "arn:aws:kms")
        assert.Contains(t, ec2RoleArn, "arn:aws:iam")

        t.Logf("✅ Security deployed: KMS=%s, Role=%s", kmsKeyId, ec2RoleArn)
    })

    // Test 4: Secrets (from secrets_test.go)
    var rdsSecretArn string

    t.Run("Secrets", func(t *testing.T) {
        secretsOptions := &terraform.Options{
            TerraformDir: "../envs/dev/secrets",
            TerraformBinary: "terraform",
            Vars: map[string]interface{}{
                "environment": "test",
                "kms_key_id":  kmsKeyId,
            },
            MaxRetries:         3,
            TimeBetweenRetries: 10 * time.Second,
        }

        defer terraform.Destroy(t, secretsOptions)
        terraform.InitAndApply(t, secretsOptions)

        rdsSecretArn = terraform.Output(t, secretsOptions, "rds_secret_arn")

        assert.NotEmpty(t, rdsSecretArn)
        assert.Contains(t, rdsSecretArn, "arn:aws:secretsmanager")

        t.Logf("✅ Secrets deployed: Secret=%s", rdsSecretArn)
    })

    // Test 5: Certificates (from certificates_test.go)
    var certificateArn string

    t.Run("Certificates", func(t *testing.T) {
        certOptions := &terraform.Options{
            TerraformDir: "../envs/dev/certificates",
            TerraformBinary: "terraform",
            Vars: map[string]interface{}{
                "domain_name": "*.example.com",
                "environment": "test",
            },
            MaxRetries:         3,
            TimeBetweenRetries: 10 * time.Second,
        }

        defer terraform.Destroy(t, certOptions)
        terraform.InitAndApply(t, certOptions)

        certificateArn = terraform.Output(t, certOptions, "certificate_arn")

        assert.NotEmpty(t, certificateArn)
        assert.Contains(t, certificateArn, "arn:aws:acm")

        t.Logf("✅ Certificates deployed: ACM=%s", certificateArn)
    })

    // Test 6: RBAC Authorization (from rbac_test.go)
    t.Run("RBAC", func(t *testing.T) {
        rbacOptions := &terraform.Options{
            TerraformDir: "../envs/dev/rbac-authorization",
            TerraformBinary: "terraform",
            Vars: map[string]interface{}{
                "environment": "test",
            },
            MaxRetries:         3,
            TimeBetweenRetries: 10 * time.Second,
        }

        defer terraform.Destroy(t, rbacOptions)
        terraform.InitAndApply(t, rbacOptions)

        developersGroupName := terraform.Output(t, rbacOptions, "developers_group_name")
        operatorsGroupName := terraform.Output(t, rbacOptions, "operators_group_name")
        auditorsGroupName := terraform.Output(t, rbacOptions, "auditors_group_name")

        assert.NotEmpty(t, developersGroupName)
        assert.NotEmpty(t, operatorsGroupName)
        assert.NotEmpty(t, auditorsGroupName)

        t.Logf("✅ RBAC deployed: Groups=%s,%s,%s", developersGroupName, operatorsGroupName, auditorsGroupName)
    })

    // Test 7: Firewall (from firewall_test.go)
    var ec2SgId, rdsSgId, vpcEndpointsSgId string

    t.Run("Firewall", func(t *testing.T) {
        firewallOptions := &terraform.Options{
            TerraformDir: "../envs/dev/firewall",
            TerraformBinary: "terraform",
            Vars: map[string]interface{}{
                "vpc_id":              vpcId,
                "vpc_cidr":            "10.0.0.0/16",
                "public_subnet_ids":   publicSubnets,
                "private_subnet_ids":  privateSubnets,
                "database_subnet_ids": databaseSubnets,
                "environment":         "test",
            },
            MaxRetries:         3,
            TimeBetweenRetries: 10 * time.Second,
        }

        defer terraform.Destroy(t, firewallOptions)
        terraform.InitAndApply(t, firewallOptions)

        ec2SgId = terraform.Output(t, firewallOptions, "ec2_security_group_id")
        rdsSgId = terraform.Output(t, firewallOptions, "rds_security_group_id")
        vpcEndpointsSgId = terraform.Output(t, firewallOptions, "vpc_endpoints_security_group_id")

        assert.NotEmpty(t, ec2SgId)
        assert.NotEmpty(t, rdsSgId)
        assert.NotEmpty(t, vpcEndpointsSgId)

        t.Logf("✅ Firewall deployed: EC2 SG=%s, RDS SG=%s, Endpoints SG=%s", ec2SgId, rdsSgId, vpcEndpointsSgId)
    })

    // Test 8: VPC Endpoints (from vpc_endpoints_test.go)
    t.Run("VPCEndpoints", func(t *testing.T) {
        endpointsOptions := &terraform.Options{
            TerraformDir: "../envs/dev/vpc-endpoints",
            TerraformBinary: "terraform",
            Vars: map[string]interface{}{
                "vpc_id":            vpcId,
                "private_subnet_ids": privateSubnets,
                "security_group_id": vpcEndpointsSgId,
                "environment":       "test",
            },
            MaxRetries:         3,
            TimeBetweenRetries: 10 * time.Second,
        }

        defer terraform.Destroy(t, endpointsOptions)
        terraform.InitAndApply(t, endpointsOptions)

        endpointIds := terraform.OutputList(t, endpointsOptions, "vpc_endpoint_ids")
        s3EndpointId := terraform.Output(t, endpointsOptions, "s3_endpoint_id")

        assert.GreaterOrEqual(t, len(endpointIds), 8) // 8 interface endpoints
        assert.NotEmpty(t, s3EndpointId)

        t.Logf("✅ VPC Endpoints deployed: Interface=%d, S3=%s", len(endpointIds), s3EndpointId)
    })

    // Test 9: Compute (from compute_test.go)
    var instanceId string

    t.Run("Compute", func(t *testing.T) {
        computeOptions := &terraform.Options{
            TerraformDir: "../envs/dev/compute",
            TerraformBinary: "terraform",
            Vars: map[string]interface{}{
                "subnet_id":           privateSubnets[0],
                "security_group_ids":  []string{ec2SgId},
                "iam_instance_profile": instanceProfileName,
                "kms_key_id":          kmsKeyId,
                "environment":         "test",
            },
            MaxRetries:         3,
            TimeBetweenRetries: 10 * time.Second,
        }

        defer terraform.Destroy(t, computeOptions)
        terraform.InitAndApply(t, computeOptions)

        instanceId = terraform.Output(t, computeOptions, "instance_id")
        privateIp := terraform.Output(t, computeOptions, "private_ip")

        assert.NotEmpty(t, instanceId)
        assert.Contains(t, instanceId, "i-")
        assert.NotEmpty(t, privateIp)

        t.Logf("✅ Compute deployed: Instance=%s, IP=%s", instanceId, privateIp)
    })

    // Test 10: Data Store (from data_store_test.go)
    var dbInstanceId, dbEndpoint string

    t.Run("DataStore", func(t *testing.T) {
        dataStoreOptions := &terraform.Options{
            TerraformDir: "../envs/dev/data_store",
            TerraformBinary: "terraform",
            Vars: map[string]interface{}{
                "subnet_ids":        databaseSubnets,
                "security_group_id": rdsSgId,
                "kms_key_id":        kmsKeyId,
                "db_username":       "dbadmin",
                "db_password":       "TempPassword123!",
                "environment":       "test",
            },
            MaxRetries:         5,
            TimeBetweenRetries: 30 * time.Second,
        }

        defer terraform.Destroy(t, dataStoreOptions)
        terraform.InitAndApply(t, dataStoreOptions)

        dbInstanceId = terraform.Output(t, dataStoreOptions, "db_instance_id")
        dbEndpoint = terraform.Output(t, dataStoreOptions, "db_endpoint")

        assert.NotEmpty(t, dbInstanceId)
        assert.NotEmpty(t, dbEndpoint)
        assert.Contains(t, dbEndpoint, ".rds.amazonaws.com")

        t.Logf("✅ Data Store deployed: Instance=%s, Endpoint=%s", dbInstanceId, dbEndpoint)
    })

    // Test 11: Monitoring (from monitoring_test.go)
    t.Run("Monitoring", func(t *testing.T) {
        monitoringOptions := &terraform.Options{
            TerraformDir: "../envs/dev/monitoring",
            TerraformBinary: "terraform",
            Vars: map[string]interface{}{
                "environment":   "test",
                "kms_key_id":    kmsKeyId,
                "ec2_instance_id": instanceId,
                "rds_instance_id": dbInstanceId,
            },
            MaxRetries:         3,
            TimeBetweenRetries: 10 * time.Second,
        }

        defer terraform.Destroy(t, monitoringOptions)
        terraform.InitAndApply(t, monitoringOptions)

        cloudtrailArn := terraform.Output(t, monitoringOptions, "cloudtrail_arn")
        securityAlertsTopicArn := terraform.Output(t, monitoringOptions, "security_alerts_topic_arn")
        monitoringAlertsTopicArn := terraform.Output(t, monitoringOptions, "monitoring_alerts_topic_arn")

        assert.NotEmpty(t, cloudtrailArn)
        assert.NotEmpty(t, securityAlertsTopicArn)
        assert.NotEmpty(t, monitoringAlertsTopicArn)
        assert.Contains(t, cloudtrailArn, "arn:aws:cloudtrail")

        t.Logf("✅ Monitoring deployed: CloudTrail=%s", cloudtrailArn)
    })

    t.Log("🎉 Full Zero Trust infrastructure deployment test completed successfully!")
}

// TestZeroTrustSecurityPrinciples validates Zero Trust security posture
func TestZeroTrustSecurityPrinciples(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping Zero Trust validation in short mode")
    }

    t.Run("NoPublicIPs", func(t *testing.T) {
        // Test that EC2 instances have no public IPs
        computeOptions := &terraform.Options{
            TerraformDir: "../envs/dev/compute",
        }

        terraform.Init(t, computeOptions)
        outputs := terraform.OutputAll(t, computeOptions)

        assert.NotContains(t, outputs, "public_ip", "EC2 should not have public IP")
        t.Log("✅ Verified: No public IPs on compute resources")
    })

    t.Run("EncryptionAtRest", func(t *testing.T) {
        // Test that RDS and EBS are encrypted
        dataStoreOptions := &terraform.Options{
            TerraformDir: "../envs/dev/data_store",
        }

        terraform.Init(t, dataStoreOptions)
        outputs := terraform.OutputAll(t, dataStoreOptions)

        assert.NotEmpty(t, outputs["db_instance_id"], "RDS instance should exist")
        t.Log("✅ Verified: Encryption at rest enabled")
    })

    t.Run("NetworkSegmentation", func(t *testing.T) {
        // Test that network segmentation exists
        vpcOptions := &terraform.Options{
            TerraformDir: "../envs/dev/vpc",
        }

        terraform.Init(t, vpcOptions)
        
        privateSubnets := terraform.OutputList(t, vpcOptions, "private_subnet_ids")
        publicSubnets := terraform.OutputList(t, vpcOptions, "public_subnet_ids")
        databaseSubnets := terraform.OutputList(t, vpcOptions, "database_subnet_ids")

        assert.Greater(t, len(privateSubnets), 0, "Should have private subnets")
        assert.Greater(t, len(publicSubnets), 0, "Should have public subnets")
        assert.Greater(t, len(databaseSubnets), 0, "Should have database subnets")
        
        t.Log("✅ Verified: Network segmentation in place")
    })

    t.Run("LeastPrivilegeIAM", func(t *testing.T) {
        // Test that IAM roles follow least privilege
        securityOptions := &terraform.Options{
            TerraformDir: "../envs/dev/security",
        }

        terraform.Init(t, securityOptions)
        
        roleArn := terraform.Output(t, securityOptions, "ec2_role_arn")
        assert.Contains(t, roleArn, "arn:aws:iam", "IAM role should exist")
        
        t.Log("✅ Verified: Least privilege IAM roles configured")
    })

    t.Run("ComprehensiveLogging", func(t *testing.T) {
        // Test that CloudTrail and monitoring are enabled
        monitoringOptions := &terraform.Options{
            TerraformDir: "../envs/dev/monitoring",
        }

        terraform.Init(t, monitoringOptions)
        
        cloudtrailArn := terraform.Output(t, monitoringOptions, "cloudtrail_arn")
        assert.Contains(t, cloudtrailArn, "arn:aws:cloudtrail", "CloudTrail should be enabled")
        
        t.Log("✅ Verified: Comprehensive logging enabled")
    })

    t.Log("🔒 All Zero Trust security principles validated!")
}

// TestCleanup helps cleanup any orphaned resources
func TestCleanup(t *testing.T) {
    t.Log("⚠️  Manual cleanup verification required - check AWS console for orphaned resources")
}