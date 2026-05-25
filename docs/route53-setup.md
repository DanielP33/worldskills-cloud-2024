# Route 53 — DNS Setup Guide
### Private Hosted Zones for `pt` and `local`

---

## Overview

Two private hosted zones handle all internal DNS resolution across the infrastructure. No `/etc/hosts` entries are used anywhere — Route 53 is the sole DNS authority for all internal names.

| Hosted Zone | Type | Purpose |
|-------------|------|---------|
| `pt` | Private | Public-facing domain names (`www.enta.pt`, `www.eppv.pt`, `www.nacional.pt`) |
| `local` | Private | Internal hostnames (`*.pdl.local`, `*.angra.local`, `intranet.angra.local`) |

Both zones are associated with all three VPCs so that every machine in the infrastructure can resolve every name.

---

## Step 1 — Create the Hosted Zones

**Route 53 → Get started → Create hosted zones**

### Zone 1 — `pt`

| Setting | Value |
|---------|-------|
| Domain name | `pt` |
| Description | `.pt` |
| Type | **Private hosted zone** |

**Associate with all three VPCs:**

| Region | VPC |
|--------|-----|
| US East (N. Virginia) | `pdl-vpc` |
| US West (Oregon) | `angra-vpc` |
| US East (N. Virginia) | `web-vpc` |

Create hosted zone.

### Zone 2 — `local`

Same configuration as `pt` — only the name and description change:

| Setting | Value |
|---------|-------|
| Domain name | `local` |
| Description | `.local` |
| Type | **Private hosted zone** |

Associate with the same three VPCs.

---

## Step 2 — Create Records

All records use **Simple routing** and a TTL of **300 seconds**.

- Use **A records** for direct IP addresses (EC2 instances, servers)
- Use **CNAME records** for load balancers (use the NLB DNS name as the value)

> To get the DNS name of a load balancer: **EC2 → Load Balancers → select the LB → Description tab → DNS name**

---

### Hosted Zone — `pt`

| Record name | Type | Value |
|-------------|------|-------|
| `www.enta.pt` | CNAME | DNS name of `lb-public` (pdl-vpc) |
| `www.eppv.pt` | A | `172.16.144.100` (`srv.angra.local` public interface) |
| `www.nacional.pt` | CNAME | DNS name of the ASG NLB (`web-vpc`) |

> For `www.enta.pt`, the value is the full NLB DNS name, e.g. `lb-8c07c39929ca35d4.elb.us-east-1.amazonaws.com`

---

### Hosted Zone — `local`

| Record name | Type | Value |
|-------------|------|-------|
| `cli.pdl.local` | A | `10.0.8.101` |
| `dmzwin.pdl.local` | A | `10.0.9.101` |
| `dmzlux.pdl.local` | A | `10.0.9.102` |
| `intrawin.angra.local` | A | `172.16.128.101` |
| `intralux.angra.local` | A | `172.16.128.102` |
| `intranet.angra.local` | CNAME | DNS name of `lb-private` (angra-vpc) |

> Add A records for any remaining hosts not listed above (`srv.pdl.local`, `srv.angra.local`, `cli.angra.local`) following the same pattern.

---

## Step 3 — Verify

From each client, confirm DNS resolution is working before the evaluation:

```bash
# From cli.pdl.local (Ubuntu)
nslookup www.enta.pt
nslookup www.nacional.pt
nslookup intranet.angra.local
nslookup dmzwin.pdl.local
nslookup dmzlux.pdl.local

# From cli.angra.local (Windows — Command Prompt)
nslookup www.eppv.pt
nslookup intranet.angra.local
nslookup intrawin.angra.local
nslookup intralux.angra.local
```

Each name should resolve to the correct IP or NLB DNS name. If resolution fails, check that the VPC has **DNS hostnames** and **DNS resolution** both enabled, and that the hosted zone is associated with that VPC.
