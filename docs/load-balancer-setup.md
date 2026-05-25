# Load Balancer Setup Guide
### `pdl-vpc` (us-east-1) and `angra-vpc` (us-west-2)

---

## Overview

| Load Balancer | Region | VPC | Scheme | Used by |
|---------------|--------|-----|--------|---------|
| `lb-private` | us-east-1 | `pdl-vpc` | Internal | `cli.pdl.local` → `www.enta.pt` |
| `lb-public` | us-east-1 | `pdl-vpc` | Internet-facing | Internet + `cli.angra.local` → `www.enta.pt` |
| `lb-private` | us-west-2 | `angra-vpc` | Internal | Both clients → `intranet.angra.local` |

All load balancers are **Network Load Balancers** (NLB). Target type is **IP addresses** for all target groups.

---

## Part 1 — us-east-1 (pdl-vpc)

### Step 1 — Create Target Groups

Create four target groups in `us-east-1`. All use **IP addresses** as target type.

---

#### Target Group 1 — `port80-private`

**Step 1 — Basic configuration:**

| Setting | Value |
|---------|-------|
| Target type | IP addresses |
| Target group name | `port80-private` |
| Protocol | TCP |
| Port | 80 |
| IP address type | IPv4 |
| VPC | `pdl-vpc` |

**Step 2 — Register targets:**

| IP Address | Port |
|------------|------|
| `10.0.9.101` | 80 |
| `10.0.9.102` | 80 |

Click **Include as pending below** after each IP, then create the target group.

---

#### Target Group 2 — `port443-private`

**Step 1 — Basic configuration:**

| Setting | Value |
|---------|-------|
| Target type | IP addresses |
| Target group name | `port443-private` |
| Protocol | TLS |
| Port | 443 |
| IP address type | IPv4 |
| VPC | `pdl-vpc` |

**Step 2 — Register targets:**

| IP Address | Port |
|------------|------|
| `10.0.9.101` | 443 |
| `10.0.9.102` | 443 |

Click **Include as pending below** after each IP, then create the target group.

---

#### Target Group 3 — `port80-public`

Same configuration as `port80-private` but with different targets:

| Setting | Value |
|---------|-------|
| Target group name | `port80-public` |
| Protocol | TCP |
| Port | 80 |
| VPC | `pdl-vpc` |

**Step 2 — Register targets:**

| IP Address | Port |
|------------|------|
| `10.0.0.100` | 80 |
| `10.0.0.100` | 8080 |

Click **Include as pending below** after each entry, then create the target group.

---

#### Target Group 4 — `port443-public`

| Setting | Value |
|---------|-------|
| Target group name | `port443-public` |
| Protocol | TLS |
| Port | 443 |
| VPC | `pdl-vpc` |

**Step 2 — Register targets:**

| IP Address | Port |
|------------|------|
| `10.0.0.100` | 443 |
| `10.0.0.100` | 8443 |

Click **Include as pending below** after each entry, then create the target group.

---

### Step 2 — Create `lb-private` (us-east-1)

**EC2 → Load Balancers → Create → Network Load Balancer**

**Basic configuration:**

| Setting | Value |
|---------|-------|
| Name | `lb-private` |
| Scheme | **Internal** |
| IP address type | IPv4 |
| VPC | `pdl-vpc` |
| Availability Zone | `us-east-1a` |
| Subnet | `pdl-subnet-private2-us-east-1a` (`10.0.9.0/24`) |
| Private IPv4 address | Assigned from CIDR |

**Security groups:**

| Security Group |
|----------------|
| `dmzlux.pdl.local-sg` |
| `dmzwin.pdl.local-sg` |

**Listeners and routing:**

| Listener | Protocol | Port | Target Group |
|----------|----------|------|--------------|
| 1 | TCP | 80 | `port80-private` |
| 2 | TLS | 443 | `port443-private` |

**TLS listener — Secure listener settings:**

| Setting | Value |
|---------|-------|
| Security policy | `ELBSecurityPolicy-TLS13-1-2-2021-06` (recommended) |
| Certificate source | **Import certificate** |
| Certificate import destination | Import to ACM (recommended) |

Retrieve the certificate and key from `srv.pdl.local`:
```bash
# Private key
sudo cat /etc/easy-rsa/pki/private/www.enta.pt.key

# Certificate body
sudo cat /etc/easy-rsa/pki/issued/www.enta.pt.crt
```

Paste into the respective fields. Certificate chain is optional.

Create the load balancer.

> **Note:** If creation fails with a TLS listener error, create the LB with only the TCP:80 listener first, then add the TLS:443 listener afterwards.

---

### Step 3 — Create `lb-public` (us-east-1)

**EC2 → Load Balancers → Create → Network Load Balancer**

**Basic configuration:**

| Setting | Value |
|---------|-------|
| Name | `lb-public` |
| Scheme | **Internet-facing** |
| IP address type | IPv4 |
| VPC | `pdl-vpc` |
| Availability Zone | `us-east-1a` |
| Subnet | `pdl-subnet-public1-us-east-1a` (`10.0.0.0/24`) |
| IPv4 address | Assigned by AWS |

**Security groups:**

| Security Group |
|----------------|
| `srv.pdl.local-sg` |

**Listeners and routing:**

| Listener | Protocol | Port | Target Group |
|----------|----------|------|--------------|
| 1 | TCP | 80 | `port80-public` |
| 2 | TLS | 443 | `port443-public` |

**TLS listener — Secure listener settings:** same as `lb-private` above — import the `www.enta.pt` certificate.

Create the load balancer.

> **Note:** Same as above — if creation fails, create with TCP:80 only and add TLS:443 after.

---

## Part 2 — us-west-2 (angra-vpc)

### Step 1 — Create Target Groups

Create two target groups in `us-west-2`.

---

#### Target Group 1 — `port80-private`

| Setting | Value |
|---------|-------|
| Target type | IP addresses |
| Target group name | `port80-private` |
| Protocol | TCP |
| Port | 80 |
| IP address type | IPv4 |
| VPC | `angra-vpc` |

**Register targets:**

| IP Address | Port |
|------------|------|
| `172.16.128.101` | 80 |
| `172.16.128.102` | 80 |

---

#### Target Group 2 — `port443-private`

| Setting | Value |
|---------|-------|
| Target type | IP addresses |
| Target group name | `port443-private` |
| Protocol | TLS |
| Port | 443 |
| IP address type | IPv4 |
| VPC | `angra-vpc` |

**Register targets:**

| IP Address | Port |
|------------|------|
| `172.16.128.101` | 443 |
| `172.16.128.102` | 443 |

---

### Step 2 — Create `lb-private` (us-west-2)

**Basic configuration:**

| Setting | Value |
|---------|-------|
| Name | `lb-private` |
| Scheme | **Internal** |
| IP address type | IPv4 |
| VPC | `angra-vpc` |
| Availability Zone | `us-west-2a` |
| Subnet | `angra-subnet-private1-us-west-2a` (`172.16.128.0/20`) |
| Private IPv4 address | Assigned from CIDR |

> AWS may warn that the selected subnet is not a private subnet and that internet traffic could reach the load balancer. This is expected given the VPC layout — the security groups restrict access appropriately.

**Security groups:**

| Security Group |
|----------------|
| `intralux.angra.local-sg` |
| `intrawin.angra.local-sg` |

**Listeners and routing:**

| Listener | Protocol | Port | Target Group |
|----------|----------|------|--------------|
| 1 | TCP | 80 | `port80-private` |
| 2 | TLS | 443 | `port443-private` |

**TLS listener — Secure listener settings:**

| Setting | Value |
|---------|-------|
| Security policy | `ELBSecurityPolicy-TLS13-1-2-2021-06` (recommended) |
| Certificate source | **Import certificate** |
| Certificate import destination | Import to ACM |

Retrieve the certificate and key from `srv.pdl.local`:
```bash
# Private key
sudo cat /etc/easy-rsa/pki/private/intranet.angra.local.key

# Certificate body
sudo cat /etc/easy-rsa/pki/issued/intranet.angra.local.crt
```

Create the load balancer.

> **Note:** Same as above — if creation fails, create with TCP:80 only and add TLS:443 after.

---

## DNS — Route 53

After all load balancers are created, create CNAME records pointing to each NLB's DNS name.

**us-east-1 (pdl-vpc hosted zone):**

| Record | Type | Value |
|--------|------|-------|
| `www.enta.pt` | CNAME | `lb-public` DNS name |
| `www.enta.pt` (internal) | CNAME | `lb-private` DNS name |

**us-west-2 (angra-vpc hosted zone):**

| Record | Type | Value |
|--------|------|-------|
| `intranet.angra.local` | CNAME | `lb-private` DNS name |

> Use the NLB DNS name from **EC2 → Load Balancers → Description tab** for each CNAME value.
