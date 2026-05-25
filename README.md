# AWS Multi-Region Cloud Infrastructure
### WorldSkills Portugal 2024 — Cloud Computing — 🥇 National Champion

> Designed and deployed a production-grade, multi-region AWS infrastructure connecting two sites across `us-east-1` and `us-west-2` — built entirely within a 21-hour competition window across 3 days.

---

## Overview

This project simulates a real-world scenario where two professional schools — **ENTA** (Ponta Delgada, Azores) and **EPPV** (Angra do Heroísmo, Azores) — migrate their IT resources to AWS. The goal: demonstrate viability by implementing a scaled-down but fully functional cloud infrastructure, including public-facing web services, private internal networks, cross-region connectivity, and a shared database tier.

The architecture was designed, configured, and validated entirely under competition conditions with no pre-built templates.

---

## Architecture

![Network Topology](diagrams/topology.png)

### Three VPCs across two AWS regions

| VPC | Region | CIDR | Purpose |
|-----|--------|------|---------|
| `pdl-vpc` | us-east-1 | 10.0.0.0/20 | ENTA — Ponta Delgada site |
| `web-vpc` | us-east-1 | 10.0.16.0/20 | Shared public web tier |
| `angra-vpc` | us-west-2 | 172.16.0.0/16 | EPPV — Angra do Heroísmo site |

Cross-region connectivity between `pdl-vpc` and `angra-vpc` is established via **VPC Peering Connection**, restricted exclusively to `PRIVATE-NET-1` on each side — no default routes permitted on those routing tables.

---

## Key Components

### 🌐 Auto Scaling Web Tier (`web-vpc`)
- EC2 Auto Scaling Group with **step scaling policy** based on CPU utilization
- 1 instance (CPU < 50%) → 2 instances (50–75%) → 3 instances (≥75%)
- Scale-in follows the same logic in reverse; last added = first removed
- Web root served from **EFS** (read-only mount on each instance) — shared filesystem across all ASG nodes
- Fronted by a **Network Load Balancer**; HTTPS only, HTTP redirects to HTTPS
- Detailed CloudWatch monitoring enabled (1-minute granularity)
- Accessible at `www.nacional.pt`

### 🔗 Cross-Region Connectivity
- VPC Peering between `pdl-vpc` (us-east-1) and `angra-vpc` (us-west-2)
- Routing restricted to PRIVATE-NET-1 ↔ PRIVATE-NET-1 only
- **No default routes** on either private routing table — intentional design to enforce network isolation

### 🗄️ RDS — MySQL (`us-east-1`)
- Single RDS MySQL instance (`northwind` identifier)
- Northwind sample database loaded and validated
- Accessible from both `cli.pdl.local` and `cli.angra.local` via MySQL Workbench

### ⚖️ Load Balancers (`pdl-vpc`)
- **Public NLB** — routes external traffic and `cli.angra.local` to `dmzwin.pdl.local` + `dmzlux.pdl.local` → `www.enta.pt`
- **Private NLB** — routes `cli.pdl.local` to same backend → `www.enta.pt`
- **Private NLB** (`angra-vpc`) — routes both clients to `intrawin.angra.local` + `intralux.angra.local` → `intranet.angra.local`

### 🔒 Certificate Authority
- Internal CA installed on `srv.pdl.local`
- Certificates issued for all internal services
- All HTTPS endpoints use valid certificates (except `https://intranet.angra.local/info.php` — cross-region constraint)

### 📦 S3
- Bucket created in `us-east-1` with randomised name
- Event notification triggers email on every upload via SNS
- Private key pairs (us-east-1 and us-west-2) stored and labelled in the bucket

### 🖥️ FTP Servers
- FTP (plain and TLS) configured on `dmzwin.pdl.local` (IIS) and `dmzlux.pdl.local` (vsftpd)
- FTP (plain and TLS) configured on `intrawin.angra.local` (IIS) and `intralux.angra.local` (vsftpd)

### 🔄 File Sync
- Web roots of `dmzwin.pdl.local` ↔ `dmzlux.pdl.local` kept in sync via S3 (max 5-minute lag)
- Web roots of `intrawin.angra.local` ↔ `intralux.angra.local` kept in sync via S3 (max 5-minute lag)

---

## Infrastructure Map

### `pdl-vpc` — us-east-1 (10.0.0.0/20)

| Host | Subnet | Type | OS | Role |
|------|--------|------|----|------|
| `srv.pdl.local` | PUBLIC-1 (10.0.0.x) | t3.small | Ubuntu | NAT, CA, SSH/RDP gateway |
| `cli.pdl.local` | PRIVATE-1 (10.0.8.x) | m5.large | Ubuntu | Client workstation |
| `dmzwin.pdl.local` | PRIVATE-2 (10.0.9.x) | m5.large | Windows Server 2022 | IIS web + FTP |
| `dmzlux.pdl.local` | PRIVATE-2 (10.0.9.x) | t3.small | Ubuntu | Apache web + vsftpd |

### `angra-vpc` — us-west-2 (172.16.0.0/16)

| Host | Subnet | Type | OS | Role |
|------|--------|------|----|------|
| `srv.angra.local` | PUBLIC (172.16.0.x) | t3.small | Amazon Linux 2023 | NAT, Nginx web, SSH/RDP gateway |
| `cli.angra.local` | PRIVATE-2 (172.16.144.x) | m5.large | Windows Server 2022 | Client workstation |
| `intrawin.angra.local` | PRIVATE-1 (172.16.128.x) | m5.large | Windows Server 2022 | IIS intranet + FTP |
| `intralux.angra.local` | PRIVATE-1 (172.16.128.x) | t3.small | Amazon Linux 2023 | Nginx intranet + vsftpd |

---

## Network Isolation Design

A key architectural decision was enforcing strict network isolation while still enabling specific cross-region communication.

**The constraint:** `PRIVATE-NET-1` on both VPCs must have **no default route**. This means:
- Machines in these subnets cannot reach the internet
- They can only reach each other via the explicitly configured peering route
- Any misconfiguration (adding a default route) would invalidate all cross-region scoring criteria

**Connectivity matrix (from `cli.pdl.local`):**

| Target | Expected | Reason |
|--------|----------|--------|
| 10.0.0.100 | ✅ Reachable | srv.pdl.local — same VPC |
| 10.0.8.100 | ✅ Reachable | cli.pdl.local — same VPC |
| 10.0.9.100–102 | ✅ Reachable | DMZ servers — same VPC |
| 172.16.128.101–102 | ✅ Reachable | intrawin/intralux — via peering (PRIVATE-1 ↔ PRIVATE-1) |
| 172.16.0.100 | ❌ Not reachable | srv.angra.local — PUBLIC subnet, not in peering scope |
| 172.16.144.100–101 | ❌ Not reachable | cli.angra.local — PRIVATE-2, not in peering scope |
| 8.8.8.8 | ✅ Reachable | Internet via NAT on srv.pdl.local |

---

## DNS

Route 53 private hosted zones configured for all internal name resolution. No `/etc/hosts` entries used anywhere.

- Type **A records** for all EC2 instances and servers
- Type **CNAME records** for all Load Balancers

---

## Ports & Remote Access

| Service | Port | Entry Point | Target Machine |
|---------|------|-------------|----------------|
| SSH | 22 | srv.pdl.local (public IP) | srv.pdl.local directly |
| SSH | 222 | srv.pdl.local (public IP) | cli.pdl.local (port-forwarded) |
| SSH | 2222 | srv.pdl.local (public IP) | dmzlux.pdl.local (port-forwarded) |
| RDP | 3389 | srv.pdl.local (public IP) | cli.pdl.local (port-forwarded) |
| RDP | 3390 | srv.pdl.local (public IP) | dmzwin.pdl.local (port-forwarded) |
| SSH | 22 | srv.angra.local (public IP) | srv.angra.local directly |
| RDP | 3389 | srv.angra.local (public IP) | cli.angra.local (port-forwarded) |
| RDP | 3390 | srv.angra.local (public IP) | intrawin.angra.local (port-forwarded) |

All security groups deny `0.0.0.0/0` except for the competition's public IP. RFC1918 address blocks are treated as trusted.

---

## Competition Context

This infrastructure was built as part of the **WorldSkills Portugal 2024 National Championship**, Skill 53 — Cloud Computing.

- **Result:** 🥇 1st place — National Champion (Regional Gold + National Gold)
- **Duration:** 21 hours over 3 competition days (November 13–15, 2024)
- **Evaluated on:** Functionality only — no partial credit for configuration that doesn't produce working results
- **Mid-competition evaluation:** Auto Scaling Group, S3 notifications, and RDS access evaluated live at end of Day 1

The competition is run by **IEFP** (Instituto do Emprego e Formação Profissional) under WorldSkills International Skill 53.

---

## Documentation

| File | Description |
|------|-------------|
| [`docs/architecture-decisions.md`](docs/architecture-decisions.md) | Why each design choice was made |
| [`docs/competition-context.md`](docs/competition-context.md) | About WorldSkills and competition rules |
| [`docs/execution-order.md`](docs/execution-order.md) | Competition day task sequence and dependencies |
| [`docs/creation-guide.md`](docs/creation-guide.md) | VPCs, instances, routing, security groups |
| [`docs/auto-scaling-group-setup.md`](docs/auto-scaling-group-setup.md) | ASG base AMI build and step scaling configuration |
| [`docs/load-balancer-setup.md`](docs/load-balancer-setup.md) | NLB target groups and listeners |
| [`docs/route53-setup.md`](docs/route53-setup.md) | Private hosted zones and DNS records |
| [`docs/rds-setup.md`](docs/rds-setup.md) | RDS MySQL instance and Northwind database |
| [`docs/website-sync-setup.md`](docs/website-sync-setup.md) | S3-based web root sync between paired servers |
| [`configs/`](configs/) | Actual server configuration files |

---

## Skills Demonstrated

`AWS VPC` `EC2 Auto Scaling` `Network Load Balancer` `EFS` `RDS MySQL` `S3 Event Notifications` `Route 53` `VPC Peering` `NAT` `Certificate Authority` `IIS` `Apache` `Nginx` `vsftpd` `CloudWatch` `IAM` `Windows Server 2022` `Ubuntu` `Amazon Linux 2023`
