# Security Documentation

Security controls and Zero Trust principles implemented in this infrastructure.

## Zero Trust Principles

This infrastructure implements the NIST SP 800-207 Zero Trust Architecture:

### Never Trust, Always Verify

```
┌────────────────────────────────────────────────────────────────────┐
│                    Zero Trust Security Model                        │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐    Verify    ┌─────────────┐    Verify    ┌────┐  │
│  │   User/     │────────────▶ │   Policy    │────────────▶│ Re-│  │
│  │   Device    │   Identity   │   Decision  │   Context   │sour│  │
│  └─────────────┘              │   Point     │             │ ce │  │
│        │                      └─────────────┘             └────┘  │
│        │                             │                            │
│        │                    ┌────────┴────────┐                   │
│        │                    │                 │                   │
│        ▼                    ▼                 ▼                   │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐           │
│  │   MFA       │    │   IAM       │    │   Network   │           │
│  │   Required  │    │   Policies  │    │   Segmented │           │
│  └─────────────┘    └─────────────┘    └─────────────┘           │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### Core Principles Implemented

| Principle | Implementation |
|-----------|----------------|
| **Least Privilege** | IAM policies grant minimum required permissions |
| **Explicit Verification** | All access requires authentication |
| **Assume Breach** | Network segmented, resources isolated |
| **Micro-segmentation** | Security groups per service |
| **Continuous Validation** | CloudTrail logging all API calls |

## Identity & Access Management

### IAM Roles (security module)

```
┌─────────────────────────────────────────────────────────────────┐
│                      IAM Role Hierarchy                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ztna-admin-role                                                │
│  └── Full administrative access (break-glass only)              │
│                                                                  │
│  ztna-readonly-role                                             │
│  └── Read-only access to all resources                         │
│                                                                  │
│  ztna-compute-role                                              │
│  └── EC2 instance profile for compute nodes                    │
│      └── Access to S3, Secrets Manager, CloudWatch             │
│                                                                  │
│  ztna-lambda-role                                               │
│  └── Lambda execution role (if applicable)                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### RBAC Authorization (rbac-authorization module)

- Role-based policies attached to groups
- No inline policies (all managed policies)
- Condition-based access (IP ranges, time windows)
- Session policies for temporary elevated access

### Best Practices Enforced

- ✅ No root account usage
- ✅ MFA required for privileged operations
- ✅ Service-linked roles where applicable
- ✅ Cross-account access via AssumeRole
- ✅ Regular access key rotation recommended

## Encryption

### Encryption at Rest

| Resource | Encryption | Key Management |
|----------|------------|----------------|
| S3 Buckets | SSE-KMS | Customer-managed KMS key |
| DynamoDB | KMS | Customer-managed KMS key |
| EBS Volumes | KMS | Customer-managed KMS key |
| Secrets Manager | KMS | Customer-managed KMS key |
| CloudTrail Logs | KMS | Customer-managed KMS key |

### Encryption in Transit

| Connection | Protocol | Certificate |
|------------|----------|-------------|
| VPC Traffic | TLS 1.2+ | ACM Private CA |
| API Gateway | HTTPS | Public ACM |
| Load Balancer | TLS 1.2+ | ACM |
| VPC Endpoints | TLS | AWS Managed |

### KMS Key Configuration (security module)

```
┌─────────────────────────────────────────────────────────────────┐
│                    KMS Key Architecture                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ztna-master-key                                                │
│  ├── Key Policy: Restrict to account principals                 │
│  ├── Key Rotation: Enabled (annual)                             │
│  ├── Deletion Protection: 30-day waiting period                 │
│  └── Usage:                                                     │
│      ├── S3 bucket encryption                                   │
│      ├── DynamoDB table encryption                              │
│      ├── EBS volume encryption                                  │
│      ├── Secrets Manager encryption                             │
│      └── CloudTrail log encryption                              │
│                                                                  │
│  Key Policy Elements:                                           │
│  ├── Key Administrators: Limited IAM roles                      │
│  ├── Key Users: Service roles only                              │
│  └── Grants: Time-limited, specific operations                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Network Security

### VPC Architecture (vpc module)

```
┌─────────────────────────────────────────────────────────────────┐
│                        VPC: 10.0.0.0/16                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                  Public Subnets (10.0.1.0/24)                ││
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                      ││
│  │  │ NAT GW  │  │   ALB   │  │ Bastion │                      ││
│  │  └────┬────┘  └─────────┘  └─────────┘                      ││
│  └───────┼──────────────────────────────────────────────────────┤│
│          │                                                       │
│  ┌───────┴──────────────────────────────────────────────────────┤│
│  │               Private Subnets (10.0.10.0/24)                 ││
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                      ││
│  │  │ App EC2 │  │ App EC2 │  │ VPC     │                      ││
│  │  │  (AZ-a) │  │  (AZ-b) │  │ Endpts  │                      ││
│  │  └─────────┘  └─────────┘  └─────────┘                      ││
│  └──────────────────────────────────────────────────────────────┤│
│                                                                  │
│  ┌──────────────────────────────────────────────────────────────┤│
│  │                Data Subnets (10.0.20.0/24)                   ││
│  │  ┌─────────┐  ┌─────────┐                                   ││
│  │  │ DB/Data │  │ DB/Data │  (No internet access)             ││
│  │  │  (AZ-a) │  │  (AZ-b) │                                   ││
│  │  └─────────┘  └─────────┘                                   ││
│  └──────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Network Firewall (firewall module)

- Stateful traffic inspection
- Domain filtering (deny-by-default)
- IPS/IDS rule groups
- Alert logging to CloudWatch

### Security Groups

| Security Group | Inbound | Outbound |
|----------------|---------|----------|
| `bastion-sg` | SSH (22) from allowed IPs | All (to VPC only) |
| `app-sg` | HTTPS (443) from ALB | HTTPS to VPC endpoints |
| `alb-sg` | HTTPS (443) from 0.0.0.0/0 | To app-sg only |
| `db-sg` | Custom ports from app-sg only | Deny all |
| `endpoint-sg` | HTTPS (443) from VPC | N/A |

### Network ACLs

- Default deny all
- Explicit allow rules per subnet type
- Logging enabled

## Secrets Management

### Secrets Manager (secrets module)

```
┌─────────────────────────────────────────────────────────────────┐
│                   Secrets Management Flow                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Application                                                     │
│      │                                                          │
│      │ 1. Request secret                                        │
│      ▼                                                          │
│  ┌─────────────┐                                                │
│  │ IAM Auth    │ ◀── Role-based access                         │
│  └──────┬──────┘                                                │
│         │                                                        │
│         │ 2. Assume role + validate                             │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │  Secrets    │ ◀── KMS encrypted                             │
│  │  Manager    │                                                │
│  └──────┬──────┘                                                │
│         │                                                        │
│         │ 3. Return decrypted secret                            │
│         ▼                                                        │
│  Application uses secret                                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Secret Types Managed

- Database credentials
- API keys
- TLS certificates/private keys
- Service account credentials

### Rotation Policy

- Automatic rotation enabled (30-day default)
- Lambda-based rotation functions
- Version tracking for rollback

## Monitoring & Logging

### CloudTrail (monitoring module)

- All management events logged
- Data events for S3 and Lambda
- Multi-region trail
- Log file validation enabled
- KMS encrypted logs

### CloudWatch

| Log Group | Source | Retention |
|-----------|--------|-----------|
| `/aws/cloudtrail/ztna` | API calls | 90 days |
| `/aws/vpc/flowlogs` | VPC traffic | 30 days |
| `/aws/firewall/alerts` | Network Firewall | 90 days |
| `/aws/ec2/ztna-*` | EC2 instances | 14 days |

### Alerts Configured

| Alert | Condition | Action |
|-------|-----------|--------|
| Root login | Root account used | SNS notification |
| Failed auth | >5 failures in 5 min | SNS notification |
| Security group change | Any modification | SNS notification |
| Large data transfer | >1GB egress | SNS notification |

## Compliance Alignment

### Frameworks Supported

| Framework | Coverage |
|-----------|----------|
| NIST 800-53 | Partial (core controls) |
| CIS AWS Benchmark | v1.4 Level 1 |
| SOC 2 Type II | Trust services criteria |
| GDPR | Data protection measures |

### Control Mapping

```
┌────────────────────────────────────────────────────────────────┐
│                Control Implementation Matrix                    │
├─────────────────────┬─────────────┬─────────────┬──────────────┤
│ Control             │ NIST        │ CIS         │ Module       │
├─────────────────────┼─────────────┼─────────────┼──────────────┤
│ Identity Management │ AC-2, IA-5  │ 1.x         │ security     │
│ Access Control      │ AC-3, AC-6  │ 1.x         │ rbac-auth    │
│ Encryption at Rest  │ SC-28       │ 2.1.x       │ security     │
│ Encryption Transit  │ SC-8        │ 2.2.x       │ certificates │
│ Network Isolation   │ SC-7        │ 5.x         │ vpc, firewall│
│ Logging             │ AU-2, AU-3  │ 3.x         │ monitoring   │
│ Secrets Management  │ IA-5        │ N/A         │ secrets      │
└─────────────────────┴─────────────┴─────────────┴──────────────┘
```

## Security Checklist

### Pre-Deployment

- [ ] AWS account hardened (root MFA, no root access keys)
- [ ] IAM password policy configured
- [ ] Billing alerts enabled
- [ ] CloudTrail enabled at organization level

### Post-Deployment

- [ ] Verify all S3 buckets are encrypted
- [ ] Verify all security groups have minimal rules
- [ ] Verify VPC flow logs are enabled
- [ ] Verify CloudTrail is logging
- [ ] Verify KMS key policies are restrictive
- [ ] Run `make test` to validate configuration

### Ongoing

- [ ] Review CloudTrail logs weekly
- [ ] Rotate access keys quarterly
- [ ] Review IAM policies monthly
- [ ] Update AMIs with security patches
- [ ] Run compliance scans monthly

## Incident Response

### Detection

1. CloudWatch Alarms trigger on anomalies
2. SNS notifications to security team
3. CloudTrail logs for forensics

### Response Playbook

```
┌─────────────────────────────────────────────────────────────────┐
│                  Security Incident Response                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. DETECT                                                       │
│     └── CloudWatch Alert / Manual Detection                     │
│                                                                  │
│  2. CONTAIN                                                      │
│     ├── Isolate affected resources (modify security groups)     │
│     ├── Revoke compromised credentials                          │
│     └── Block malicious IPs (Network Firewall)                  │
│                                                                  │
│  3. INVESTIGATE                                                  │
│     ├── Review CloudTrail logs                                  │
│     ├── Analyze VPC flow logs                                   │
│     └── Examine affected resources                              │
│                                                                  │
│  4. REMEDIATE                                                    │
│     ├── Patch vulnerabilities                                   │
│     ├── Rotate secrets/keys                                     │
│     └── Update security controls                                │
│                                                                  │
│  5. RECOVER                                                      │
│     ├── Restore from clean backups if needed                    │
│     ├── Redeploy affected resources                             │
│     └── Verify integrity                                        │
│                                                                  │
│  6. DOCUMENT                                                     │
│     └── Post-incident report and lessons learned                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```
