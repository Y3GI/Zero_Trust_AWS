# Architecture

## Zero Trust Network Architecture (ZTNA)

This infrastructure implements Zero Trust principles where **no user, device, or service is trusted by default**, even if inside the network perimeter.

## Core Principles

1. **Never Trust, Always Verify** - All access requests are authenticated and authorized
2. **Least Privilege Access** - Minimal permissions for every identity
3. **Assume Breach** - Design as if attackers are already inside
4. **Micro-Segmentation** - Network divided into small, isolated zones
5. **Continuous Monitoring** - All activities logged and analyzed

## Infrastructure Layers

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Layer 1: Foundation (Bootstrap)                                         │
├─────────────────────────────────────────────────────────────────────────┤
│ ┌──────────────────┐         ┌──────────────────┐                       │
│ │ S3 Bucket        │         │ S3 Bucket        │                       │
│ │ (Terraform State)│         │ (CloudTrail Logs)│                       │
│ └──────────────────┘         └──────────────────┘                       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Layer 2: Identity & Encryption (Security)                               │
├─────────────────────────────────────────────────────────────────────────┤
│ ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐        │
│ │ IAM Roles        │  │ KMS Keys         │  │ Instance         │        │
│ │ (App, Flow, CT)  │  │ (Encryption)     │  │ Profiles         │        │
│ └──────────────────┘  └──────────────────┘  └──────────────────┘        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Layer 3: Network Foundation (VPC)                                       │
├─────────────────────────────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────────────────────┐        │
│ │ VPC (10.0.0.0/16)                                            │        │
│ │ ┌────────────────┐ ┌────────────────┐ ┌────────────────┐     │        │
│ │ │ Public Subnet  │ │ Private Subnet │ │ Isolated Subnet│     │        │
│ │ │ 10.0.1.0/24    │ │ 10.0.2.0/24    │ │ 10.0.3.0/24    │     │        │
│ │ │ (Bastion/NAT)  │ │ (App Servers)  │ │ (Databases)    │     │        │
│ │ └────────────────┘ └────────────────┘ └────────────────┘     │        │
│ └──────────────────────────────────────────────────────────────┘        │
│                                                                         │
│ ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│ │ Internet GW │  │ NAT Gateway │  │ Route Tables│  │ Flow Logs   │      │
│ └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Layer 4: Network Security (Firewall + VPC Endpoints)                    │
├─────────────────────────────────────────────────────────────────────────┤
│ ┌──────────────────┐  ┌──────────────────────────────────────────┐      │
│ │ AWS Network      │  │ VPC Endpoints (Private AWS Access)       │      │
│ │ Firewall         │  │ • S3 Gateway        • Secrets Manager    │      │
│ │ (Stateful Rules) │  │ • DynamoDB Gateway  • SSM/EC2 Messages   │      │
│ │                  │  │ • CloudWatch Logs   • KMS                │      │
│ └──────────────────┘  └──────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Layer 5: Compute & Data                                                 │
├─────────────────────────────────────────────────────────────────────────┤
│ ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐        │
│ │ Bastion Host     │  │ App Server       │  │ DynamoDB         │        │
│ │ (Public Subnet)  │  │ (Private Subnet) │  │ (Encrypted)      │        │
│ │ Session Manager  │  │ IMDSv2 Required  │  │ State Locking    │        │
│ └──────────────────┘  └──────────────────┘  └──────────────────┘        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Layer 6: Secrets & Certificates                                         │
├─────────────────────────────────────────────────────────────────────────┤
│ ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐        │
│ │ Secrets Manager  │  │ ACM Private CA   │  │ RBAC Policies    │        │
│ │ • DB Credentials │  │ • Root CA        │  │ • Bastion Policy │        │
│ │ • API Keys       │  │ • mTLS Certs     │  │ • App Policy     │        │
│ └──────────────────┘  └──────────────────┘  └──────────────────┘        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Layer 7: Monitoring & Compliance                                        │
├─────────────────────────────────────────────────────────────────────────┤
│ ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐        │
│ │ CloudTrail       │  │ CloudWatch       │  │ AWS Budgets      │        │
│ │ (API Audit)      │  │ (Metrics/Alarms) │  │ (Cost Alerts)    │        │
│ └──────────────────┘  └──────────────────┘  └──────────────────┘        │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Inbound Traffic Flow

```
Internet → Internet Gateway → Public Subnet → NAT Gateway → Private Subnet → App Server
                                    ↓
                            Network Firewall
                            (Inspection)
```

### AWS Service Access Flow (Zero Trust)

```
App Server → VPC Endpoint → AWS Service
    ↓              ↓
 No Internet   Private IP
```

### Secrets Access Flow

```
App Server → IAM Role → Secrets Manager VPC Endpoint → Secret
    ↓            ↓                  ↓
Instance    Temporary         Private Path
Profile     Credentials       (No Internet)
```

## Security Controls Matrix

| Layer | Control | Implementation |
|-------|---------|----------------|
| Network | Segmentation | Public/Private/Isolated subnets |
| Network | Firewall | AWS Network Firewall with rules |
| Network | Traffic Inspection | VPC Flow Logs |
| Identity | Authentication | IAM roles, no static credentials |
| Identity | Authorization | RBAC policies, least privilege |
| Data | Encryption at Rest | KMS customer-managed keys |
| Data | Encryption in Transit | TLS 1.2+, VPC endpoints |
| Secrets | Management | Secrets Manager with rotation |
| Compute | Hardening | IMDSv2, Session Manager |
| Audit | Logging | CloudTrail, CloudWatch Logs |
| Cost | Monitoring | AWS Budgets with alerts |

## Module Dependencies

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  bootstrap  │     │  security   │     │     vpc     │
│ (Independent)│     │(Independent)│     │(Independent)│
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ monitoring  │◄────┤   secrets   │     │  firewall   │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│vpc-endpoints│◄────┤  data_store │     │   compute   │
└─────────────┘     └─────────────┘     └─────────────┘
```

## Region Configuration

- **Primary Region**: `eu-north-1` (Stockholm)
- **VPC CIDR**: `10.0.0.0/16`
- **Availability Zones**: Single AZ (`eu-north-1a`) - expand for production

## Compliance Alignment

This architecture aligns with:

- **NIST 800-207** - Zero Trust Architecture
- **AWS Well-Architected Framework** - Security Pillar
- **CIS AWS Foundations Benchmark**
- **GDPR** - Data protection requirements (EU region)
