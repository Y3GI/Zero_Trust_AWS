# Wildcard Policy Remediation Guide

## 📍 Problem: Asterisks (*) in Policies

You asked: **"there are some * in the endpoints and other places what should i do with them"**

Answer: Replace them with specific, restrictive ARNs and conditions. This is a critical security issue.

---

## 🔴 Location 1: VPC Endpoints (modules/vpc-endpoints/main.tf)

### Current (Too Permissive)
```hcl
# ❌ BAD - Allows any S3 action
policy = jsonencode({
  Statement = [{
    Principal = "*"
    Action = "s3:*"
    Resource = "*"
  }]
})
```

### Fixed (Restrictive)
```hcl
# ✅ GOOD - Only CloudTrail put operations
policy = jsonencode({
  Statement = [{
    Principal = {
      Service = "cloudtrail.amazonaws.com"
    }
    Action = [
      "s3:PutObject",
      "s3:GetBucketVersioning"
    ]
    Resource = [
      aws_s3_bucket.cloudtrail.arn,
      "${aws_s3_bucket.cloudtrail.arn}/*"
    ]
  }]
})
```

### What to Change
Replace general resource policies with:
- **Specific service principals** (not "*")
- **Specific actions** (not "s3:*")
- **Specific resources** (CloudTrail bucket ARN)

---

## 🔴 Location 2: RBAC Authorization (modules/rbac-authorization/main.tf)

### Current (Too Permissive)
```hcl
# ❌ BAD - App can access ANY KMS key
{
  Effect   = "Allow"
  Action   = "kms:*"
  Resource = "*"
}
```

### Fixed (Restrictive)
```hcl
# ✅ GOOD - App can only use specific KMS key
{
  Effect = "Allow"
  Action = [
    "kms:Decrypt",
    "kms:DescribeKey",
    "kms:GenerateDataKey"
  ]
  Resource = "arn:aws:kms:*:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}"
}
```

### Pattern: Replace Resource Wildcards with Specific ARNs

**Generic → Specific**
| Bad | Good |
|-----|------|
| `Resource = "*"` | `Resource = arn:aws:kms:...:key/xyz` |
| `Action = "s3:*"` | `Action = ["s3:GetObject", "s3:PutObject"]` |
| `Principal = "*"` | `Principal = { Service = "ec2.amazonaws.com" }` |

---

## 🔴 Location 3: Secrets Manager Resource Policies

### Current (If Using Wildcards)
```hcl
# ❌ BAD - Anyone with IAM can retrieve
{
  Effect   = "Allow"
  Action   = "secretsmanager:*"
  Resource = "*"
}
```

### Fixed (Restrictive)
```hcl
# ✅ GOOD - Only app tier role can retrieve
{
  Effect = "Allow"
  Action = [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret"
  ]
  Resource = [
    aws_secretsmanager_secret.db_credentials.arn,
    aws_secretsmanager_secret.api_keys.arn
  ]
  Principal = {
    AWS = var.app_role_arn
  }
}
```

---

## 🛠️ How to Fix: Step-by-Step

### Step 1: Identify All Wildcards
```bash
# Search for wildcards in Terraform files
grep -r "\*" modules/vpc-endpoints/*.tf | grep -E 'Action|Resource|Principal'
grep -r "\*" modules/rbac-authorization/*.tf | grep -E 'Action|Resource|Principal'
grep -r "\*" modules/secrets/*.tf | grep -E 'Action|Resource'
```

### Step 2: For Each Wildcard, Ask:

1. **Is this an Action wildcard?** (`Action = "service:*"`)
   - Replace with specific actions: `["service:GetObject", "service:PutObject"]`
   - List only the actions needed

2. **Is this a Resource wildcard?** (`Resource = "*"`)
   - Replace with specific ARNs
   - Use variables for flexibility: `var.kms_key_arn`

3. **Is this a Principal wildcard?** (`Principal = "*"`)
   - Replace with specific service or role
   - Option: Use conditions instead

### Step 3: Test the Permissions
After changes, verify:
- ✅ Intended service CAN access resource
- ✅ Unintended service CANNOT access resource

---

## 📋 Complete Remediation Checklist

### VPC Endpoints Module
- [ ] S3 endpoint policy - restrict to CloudTrail bucket only
- [ ] Secrets Manager endpoint - restrict to specific secret ARNs
- [ ] SSM/EC2Messages - restrict to ec2.amazonaws.com
- [ ] KMS endpoint - restrict to KMS key ARN
- [ ] DynamoDB endpoint - restrict to specific table ARN
- [ ] Security group - keep port 443 only, restrict source to VPC CIDR

### RBAC Authorization Module
- [ ] KMS actions - restrict to specific key ARN
- [ ] Secrets Manager - restrict to specific secret ARNs
- [ ] DynamoDB - restrict to specific table ARN
- [ ] CloudWatch Logs - restrict to specific log group ARN
- [ ] S3 - restrict to specific bucket/prefix
- [ ] EC2/SSM - use conditions with tags

### Secrets Module
- [ ] Secret resource policy - restrict Principal to app role only
- [ ] Lambda rotation - if added, restrict to rotation function only

---

## 🎯 Universal Fix Template

Whenever you see a wildcard, ask: **"What is the minimum permission needed?"**

**Template:**
```hcl
# Before
{
  Effect = "Allow"
  Action = "SERVICE:*"
  Resource = "*"
}

# After
{
  Effect = "Allow"
  Action = [
    "SERVICE:SpecificAction1",
    "SERVICE:SpecificAction2"
  ]
  Resource = "arn:aws:SERVICE:REGION:ACCOUNT:RESOURCE/PATH"
  Condition = {
    StringEquals = {
      "aws:ResourceTag/Environment" = "production"
    }
  }
}
```

**Key Changes:**
1. Specific actions (not `*`)
2. Specific resources (not `*`)
3. Specific principals (not `*`)
4. Add conditions when possible (time-based, tag-based, IP-based)

---

## 💡 Real-World Examples from Your Setup

### Example 1: App Tier Accessing Secrets

**Bad:**
```hcl
Statement {
  Effect = "Allow"
  Action = "secretsmanager:*"
  Resource = "*"
}
```

**Good:**
```hcl
Statement {
  Effect = "Allow"
  Action = [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret"
  ]
  Resource = [
    "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:db-credentials*",
    "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:api-keys*"
  ]
}
```

### Example 2: VPC Endpoint for S3

**Bad:**
```hcl
policy = jsonencode({
  Statement = [{
    Effect = "Allow"
    Principal = "*"
    Action = "s3:*"
    Resource = "*"
  }]
})
```

**Good:**
```hcl
policy = jsonencode({
  Statement = [
    {
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action = [
        "s3:PutObject",
        "s3:GetBucketVersioning"
      ]
      Resource = [
        "arn:aws:s3:::${var.cloudtrail_bucket_name}",
        "arn:aws:s3:::${var.cloudtrail_bucket_name}/*"
      ]
      Condition = {
        StringEquals = {
          "s3:x-amz-acl" = "bucket-owner-full-control"
        }
      }
    }
  ]
})
```

### Example 3: RBAC Authorization for KMS

**Bad:**
```hcl
Statement {
  Effect = "Allow"
  Action = "kms:*"
  Resource = "*"
}
```

**Good:**
```hcl
Statement {
  Effect = "Allow"
  Action = [
    "kms:Decrypt",
    "kms:GenerateDataKey",
    "kms:DescribeKey"
  ]
  Resource = "arn:aws:kms:${var.region}:${var.account_id}:key/${var.kms_key_id}"
  Condition = {
    StringEquals = {
      "aws:ResourceTag/Environment" = var.environment
    }
  }
}
```

---

## ✅ Validation After Changes

### Check 1: Syntax
```bash
cd envs/dev
terraform validate
```

### Check 2: Plan
```bash
terraform plan -target=module.vpc_endpoints
terraform plan -target=module.rbac_authorization
terraform plan -target=module.secrets
```

### Check 3: Policy Validation
```bash
# Use AWS policy simulator
aws accessanalyzer validate-policy \
  --policy-document file://policy.json \
  --policy-type IDENTITY_POLICY
```

### Check 4: Real-World Test
After deployment:
1. Try to access from authorized principal → should work ✅
2. Try to access from unauthorized principal → should fail ❌

---

## 🚨 Common Mistakes to Avoid

### ❌ Don't Do This
```hcl
# Still too permissive
Action = "kms:*"
Resource = "arn:aws:kms:*:account:*"

# Wildcards in conditions
Condition = {
  StringEquals = {
    "aws:username" = "*"
  }
}

# Principal wildcards for resources
Principal = "*"
Condition = {
  StringEquals = {
    "aws:SourceVpc" = var.vpc_id
  }
}
```

### ✅ Do This Instead
```hcl
# Specific actions only
Action = [
  "kms:Decrypt",
  "kms:GenerateDataKey",
  "kms:DescribeKey"
]

# Specific resources with conditions
Resource = "arn:aws:kms:${var.region}:${var.account_id}:key/${var.kms_key_id}"
Condition = {
  StringEquals = {
    "aws:username" = var.app_username
  }
}

# Specific principals
Principal = {
  AWS = var.app_role_arn
}
Condition = {
  StringEquals = {
    "aws:SourceVpc" = var.vpc_id
  }
}
```

---

## 📊 Security Impact

| Wildcard Type | Risk Level | Impact |
|---|---|---|
| `Action = "*"` | 🔴 CRITICAL | Service compromise |
| `Resource = "*"` | 🔴 CRITICAL | Cross-account attacks |
| `Principal = "*"` | 🔴 CRITICAL | Unauthorized access |
| `Condition = "*"` | 🟡 HIGH | Overly broad access |

**Action Required:** Fix all critical wildcards before production deployment.

---

## ✨ After Remediation

Your ZTNA will:
- ✅ Follow principle of least privilege
- ✅ Prevent privilege escalation
- ✅ Reduce attack surface
- ✅ Pass security audits
- ✅ Be production-ready

