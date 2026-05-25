# Auto Scaling Group — web-vpc (us-east-1)

## Overview

Hosts `www.nacional.pt` — shared public web tier used by both ENTA and EPPV.

## VPC / Subnet
- VPC: `web-vpc` (10.0.16.0/20)
- Subnets: All 3 public subnets across 3 Availability Zones
- Internet-facing NLB spans all 3 AZs

## Launch Template

| Setting | Value |
|---------|-------|
| Instance type | M5.large |
| AMI | Amazon Linux 2023 (Quick Start) |
| Volume | 30 GiB |
| Detailed monitoring | Enabled (1-minute CloudWatch metrics) |
| Key pair | us-east-1 key pair |

### User Data (bootstrap)

```bash
#!/bin/bash
# Mount EFS
yum install -y amazon-efs-utils
mkdir -p /var/www/html
mount -t efs -o tls,ro fs-XXXXXXXX:/ /var/www/html

# Install Apache + PHP
yum install -y httpd php
systemctl enable httpd
systemctl start httpd

# Install stress-ng (required for ASG evaluation)
yum install -y stress-ng

# HTTPS redirect — HTTP -> HTTPS handled at NLB listener level
```

## EFS Configuration
- Filesystem mounted read-only (`ro`) on all ASG instances
- Web root: `/var/www/html`
- Content updated once on EFS, propagates to all instances instantly

## Auto Scaling Configuration

| Setting | Value |
|---------|-------|
| Minimum capacity | 1 |
| Desired capacity | 1 |
| Maximum capacity | 3 |
| Warm-up | 60 seconds |
| Cooldown | 60 seconds |
| Instance refresh | 60 seconds |

## Step Scaling Policy

### Scale-Out
| Condition | Action |
|-----------|--------|
| CPUUtilization < 50% | 1 instance |
| 50% ≤ CPUUtilization < 75% | 2 instances |
| CPUUtilization ≥ 75% | 3 instances |

### Scale-In (same thresholds, reverse logic)
| Condition | Action |
|-----------|--------|
| CPUUtilization drops below 75% | Remove 1 (most recently added first) |
| CPUUtilization drops below 50% | Remove 1 (back to 1 instance) |

## Network Load Balancer

- Scheme: Internet-facing
- Listeners: Port 80 (redirect to 443), Port 443 (HTTPS)
- Target group: ASG instances
- DNS: `www.nacional.pt` (Route 53 CNAME → NLB DNS name)

## Testing ASG Scaling

```bash
# SSH into a running ASG instance
# Run stress-ng to simulate load
./scripts/stress-test.sh 70   # ~70% CPU load -> should trigger 2 instances
./scripts/stress-test.sh 80   # ~80% CPU load -> should trigger 3 instances
```

Monitor in CloudWatch → EC2 → CPUUtilization for the ASG.
Expect scale-out within ~2 minutes (1-minute metric + 60s warm-up).
