# VPC Endpoints for ZTNA - What's Included

## Overview
VPC Endpoints enable private communication between your VPC and AWS services, preventing data from traversing the public internet. This is **critical for ZTNA's "Assume Breach" principle**.

---

## ✅ Endpoints Implemented in vpc-endpoints Module

### **1. S3 Gateway Endpoint** 🚪
```
Service: com.amazonaws.region.s3
Type: Gateway
Purpose: CloudTrail logs storage (private route)
```
- ✅ Attached to route tables (public + private)
- ✅ S3 bucket policy restricts to CloudTrail bucket
- ✅ Prevents CloudTrail logs from crossing internet

**Security:**
```terraform
# Only allows CloudTrail to write to audit logs
Resource = [
    "arn:aws:s3:::${var.cloudtrail_bucket_name}",
    "arn:aws:s3:::${var.cloudtrail_bucket_name}/*"
]
```

---

### **2. Secrets Manager Interface Endpoint** 🔐
```
Service: com.amazonaws.region.secretsmanager
Type: Interface (ENI in subnets)
Purpose: Retrieve database credentials and API keys
```
- ✅ Deployed in private subnets
- ✅ Private DNS enabled (apps use secretsmanager.region.amazonaws.com)
- ✅ Security group restricts to HTTPS from VPC
- ✅ KMS encrypted secrets in transit

**Benefits for ZTNA:**
- Applications retrieve secrets without traversing internet
- No exposure of credential transport
- Complete audit trail via CloudTrail

---

### **3. Systems Manager (SSM) Endpoint** 📋
```
Service: com.amazonaws.region.ssm
Type: Interface
Purpose: Parameter Store, automation, patch management
```
- ✅ For Systems Manager Session Manager (credential-less access)
- ✅ Private DNS enabled
- ✅ Required for EC2 to contact SSM service

**Why it matters for ZTNA:**
- Enables credential-less remote access without SSH keys
- Session connections stay within VPC
- Full session recording to CloudWatch

---

### **4. EC2 Messages Endpoint** 📨
```
Service: com.amazonaws.region.ec2messages
Type: Interface
Purpose: EC2 to SSM agent communication
```
- ✅ Required for Systems Manager Session Manager
- ✅ Allows EC2 instances to send messages to SSM service
- ✅ Private communication channel

---

### **5. SSM Messages Endpoint** 💬
```
Service: com.amazonaws.region.ssmmessages
Type: Interface
Purpose: Session Manager session data transfer
```
- ✅ Handles encrypted session messages
- ✅ KMS encrypted end-to-end
- ✅ Audit logged to CloudTrail

---

### **6. STS Endpoint (Security Token Service)** 🎫
```
Service: com.amazonaws.region.sts
Type: Interface
Purpose: IAM credential federation, temporary credentials
```
- ✅ Enables AssumeRole operations without internet
- ✅ Cross-account access stays private
- ✅ Required for service-to-service authentication

**Use case for ZTNA:**
```
App Server assumes role with STS
    ↓
Retrieves temporary credentials
    ↓
Uses credentials to access other AWS services
    ↓
All communication stays in VPC (no internet exposure)
```

---

### **7. CloudWatch Logs Endpoint** 📊
```
Service: com.amazonaws.region.logs
Type: Interface
Purpose: Send application logs to CloudWatch
```
- ✅ VPC Flow Logs write to CloudWatch privately
- ✅ CloudTrail events logged privately
- ✅ Application logs sent without internet access

**ZTNA benefit:**
- Audit trail secure from data exfiltration
- Attackers can't block logging by cutting internet

---

### **8. KMS Endpoint** 🔑
```
Service: com.amazonaws.region.kms
Type: Interface
Purpose: Encrypt/decrypt data, decrypt secrets
```
- ✅ All encryption operations stay in VPC
- ✅ Secrets Manager uses this for decryption
- ✅ DynamoDB uses this for encryption

**Security chain:**
```
App → Requests secret from Secrets Manager (via endpoint)
    ↓
Secrets Manager → Requests KMS decryption (via endpoint)
    ↓
KMS → Returns decrypted secret
    ↓
Secret → Returns to app (via endpoint)
All in VPC, no internet exposure!
```

---

## 📊 Network Flow - Before vs After

### ❌ **Without VPC Endpoints** (High Risk)
```
EC2 Instance (10.0.2.x)
    ↓
Requests credential from Secrets Manager
    ↓
NAT Gateway (10.0.1.x)
    ↓
Internet Gateway
    ↓
🌐 PUBLIC INTERNET 🌐
    ↓
AWS Secrets Manager Service
    ↓
Back through Internet Gateway
    ↓
NAT Gateway
    ↓
EC2 Instance

⚠️ Risk: Data crosses public internet, can be intercepted!
```

### ✅ **With VPC Endpoints** (ZTNA Secure)
```
EC2 Instance (10.0.2.x)
    ↓ HTTPS (private)
Secrets Manager Endpoint (10.0.2.x)
    ↓
AWS Secrets Manager Service (private pathway)
    ↓
KMS Endpoint (10.0.2.x)
    ↓
AWS KMS Service (private pathway)
    ↓
Returns decrypted secret
    ↓
EC2 Instance

✅ Safe: All communication within VPC, no internet exposure!
```

---

## 🔒 Security Group Configuration

All Interface endpoints share the same security group:

```terraform
ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Your VPC CIDR
}
```

**Why HTTPS (443)?**
- All AWS service APIs use HTTPS
- Data encrypted in transit
- Certificate validation prevents MITM attacks

---

## 📋 What Gets Added to Route Tables

### **Private Route Table**
```
Destination           | Target
─────────────────────────────────
10.0.0.0/16          | Local VPC
0.0.0.0/0            | NAT Gateway (for internet access if needed)
*.secretsmanager.vpce| S3 Endpoint (automatic)
*.kms.vpce           | KMS Endpoint (automatic)
*.ssm.vpce           | SSM Endpoint (automatic)
... etc for others
```

Routes are automatically created for Interface endpoints!

---

## 💡 Endpoint Costs

| Endpoint Type | Cost Model | Approximate Cost |
|---------------|-----------|------------------|
| Gateway (S3) | Free | $0 |
| Interface | Per hour + data processed | ~$7.20/month each |

**For this setup:** ~8 interfaces × $7.20 = **~$60/month**
**Value:** Prevents data exfiltration, enables ZTNA ✅

---

## 🔍 How to Verify Endpoints Are Working

```bash
# 1. SSH to bastion
aws ssm start-session --target i-xxxxxxxxx --document-name AWS-StartInteractiveCommand

# 2. From private instance, check endpoint DNS
nslookup secretsmanager.eu-north-1.amazonaws.com

# Should return private IP like 10.0.x.x (not public IP!)

# 3. Test connectivity to endpoint
curl https://secretsmanager.eu-north-1.amazonaws.com

# 4. Check CloudTrail for VPC endpoint activity
```

---

## ⚡ Integration with Secrets Module

When you add the Secrets Manager module, flow is:

```
Application running on EC2
    ↓
AWS SDK call: GetSecretValue("db-credentials")
    ↓
Uses Secrets Manager Endpoint (private)
    ↓
SM: Decrypt with KMS
    ↓
Uses KMS Endpoint (private)
    ↓
Returns encrypted credentials to SM
    ↓
SM returns decrypted secret to app
    ↓
App uses credentials (never stored locally)
```

---

## 🛠️ Adding to Your Infrastructure

### **Step 1: Update VPC Module in env/dev**

In `envs/dev/vpc/main.tf`, add after VPC module:

```terraform
# Get bootstrap outputs
data "terraform_remote_state" "bootstrap" {
    backend = "local"
    config = { path = "../bootstrap/terraform.tfstate" }
}

# Add VPC endpoints module
module "vpc_endpoints" {
    source = "../../../modules/vpc-endpoints"
    
    vpc_id                   = module.vpc.vpc_id
    vpc_cidr                 = "10.0.0.0/16"
    private_subnet_ids       = module.vpc.private_subnet_ids
    route_table_ids          = [module.vpc.private_rt_id, module.vpc.public_rt_id]
    cloudtrail_bucket_name   = data.terraform_remote_state.bootstrap.outputs.cloudtrail_bucket_name
}

# Export endpoints
output "vpc_endpoints_security_group" {
    value = module.vpc_endpoints.vpc_endpoints_security_group_id
}
```

### **Step 2: Deploy**
```bash
cd envs/dev/vpc
terraform apply
```

### **Step 3: Verify**
```bash
# Check endpoints created
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=<your-vpc-id>"
```

---

## 🎯 ZTNA Principles Enabled by VPC Endpoints

| Principle | How Endpoints Help |
|-----------|-------------------|
| **Never Trust** | Credentials transmitted securely through private endpoints |
| **Always Verify** | All connections logged via CloudTrail (immutable) |
| **Assume Breach** | Even if EC2 compromised, data can't exfiltrate via internet |
| **Verify Explicitly** | Security groups enforce access control |
| **Defense in Depth** | Multiple layers: SG + private routing + encryption |
| **Continuous Monitoring** | All endpoint traffic logged to CloudTrail |

---

## ✨ Summary

You now have a **secure, ZTNA-compliant** network layer where:
- ✅ All AWS service communication stays private
- ✅ Data cannot be exfiltrated to internet
- ✅ Complete audit trail of all communication
- ✅ Encryption both at rest and in transit
- ✅ Zero internet dependencies for core operations

This is one of the **most critical components** for achieving true Zero Trust Architecture!

