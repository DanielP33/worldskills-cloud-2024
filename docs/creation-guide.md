# Infrastructure Creation Guide
### Full setup walkthrough for VPCs, Transit Gateway, S3, Instances, Routing, Security Groups

---

## 1. VPCs

Create three VPCs — two in `us-east-1` and one in `us-west-2`. Use the **VPC and more** creation wizard so subnets, route tables, and the S3 gateway endpoint are created automatically.

> Optionally rename any pre-existing default VPCs to `DEFAULT VPC` to avoid confusion.

---

### `pdl-vpc` — us-east-1

| Setting | Value |
|---------|-------|
| Name | `pdl` ← the wizard auto-generates `pdl-vpc` |
| IPv4 CIDR | `10.0.0.0/20` |
| IPv6 CIDR | None |
| Tenancy | Default |
| Availability Zones | 1 |
| Public subnets | 1 |
| Private subnets | 2 |
| NAT gateways | None |
| VPC endpoints | S3 Gateway |
| DNS hostnames | Enabled |
| DNS resolution | Enabled |

---

### `web-vpc` — us-east-1

| Setting | Value |
|---------|-------|
| Name | `web` ← the wizard auto-generates `web-vpc` |
| IPv4 CIDR | `10.0.16.0/20` |
| IPv6 CIDR | None |
| Tenancy | Default |
| Availability Zones | 3 |
| Public subnets | 3 |
| Private subnets | 0 |
| NAT gateways | None |
| VPC endpoints | S3 Gateway |
| DNS hostnames | Enabled |
| DNS resolution | Enabled |

---

### `angra-vpc` — us-west-2

| Setting | Value |
|---------|-------|
| Name | `angra-vpc` |
| IPv4 CIDR | `172.16.0.0/16` |
| IPv6 CIDR | AWS-provided |
| Tenancy | Default |
| Availability Zones | 1 |
| Public subnets | 1 |
| Private subnets | 2 |
| NAT gateways | None |
| Egress-only Internet Gateway | Yes |
| VPC endpoints | S3 Gateway |
| DNS hostnames | Enabled |
| DNS resolution | Enabled |

---

## 2. Cross-Region Connectivity

On competition day, the connectivity method between `pdl-vpc` and `angra-vpc` was confirmed as a **VPC Peering Connection**.

The peering connects `PRIVATE-NET-1` of `pdl-vpc` (`10.0.8.0/24`) to `PRIVATE-NET-1` of `angra-vpc` (`172.16.128.0/20`) exclusively. Routing tables for both private subnets have **no default route** — only the explicit peering route.

> If you are recreating this with a Transit Gateway instead, the attachment and peering steps are similar but require two Transit Gateways (one per region) connected via a TGW peering attachment. Accept the peering request from the **receiving region** (not the one that initiated it).

---

## 3. S3 Bucket

Go to **S3 → Create Bucket**.

| Setting | Value |
|---------|-------|
| Bucket name | `firstnamelastname12345` ← replace with your name + 5 random digits |
| Region | `us-east-1` |

### SNS Notification on Upload

**Go to Amazon SNS → Topics → Create Topic**

| Setting | Value |
|---------|-------|
| Type | Standard |
| Name | `s3notification` |

Create the topic, then:

**Create Subscription**
| Setting | Value |
|---------|-------|
| Protocol | Email |
| Endpoint | `[compemail]@enta.pt` |

Confirm the subscription via the email that arrives.

### Update the SNS Access Policy

Go back to the `s3notification` topic → **Edit → Access Policy**.

Replace the default policy with one that allows S3 to publish to this topic. The policy should permit `sns:Publish` from the S3 service principal, scoped to your bucket's ARN as the source. The topic ARN is shown at the top of the topic page — update it accordingly.

Example structure:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "s3.amazonaws.com" },
      "Action": "SNS:Publish",
      "Resource": "arn:aws:sns:us-east-1:ACCOUNT_ID:s3notification",
      "Condition": {
        "ArnLike": {
          "aws:SourceArn": "arn:aws:s3:::YOUR_BUCKET_NAME"
        }
      }
    }
  ]
}
```

### Configure the S3 Event Notification

**S3 → your bucket → Properties → Event Notifications → Create**

| Setting | Value |
|---------|-------|
| Name | `upload-notification` |
| Event types | All object create events (`s3:ObjectCreated:*`) |
| Destination | SNS Topic → `s3notification` |

Test by uploading a file — an email notification should arrive at `[compemail]@enta.pt`.

---

## 4. EC2 Instances

All instances use IAM Instance Profile: `LabInstanceProfile` — apply this to every machine without exception.

---

### `srv.pdl.local` — us-east-1

| Setting | Value |
|---------|-------|
| OS | Ubuntu |
| Instance type | `t3.small` |
| Key pair | Create new: `east1-yourname` |
| VPC | `pdl-vpc` |
| Subnet | Public subnet |
| Volume | 30 GiB |
| IAM Instance Profile | `LabInstanceProfile` |

**Network interfaces — assign static private IPs:**

| Interface | Subnet | IP |
|-----------|--------|----|
| Primary (eth0) | Public | `10.0.0.100` |
| Secondary (eth1) | Private-1 | `10.0.8.100` |
| Secondary (eth2) | Private-2 | `10.0.9.100` |

After launch, allocate and associate an **Elastic IP** to the public interface.

---

### `cli.pdl.local` — us-east-1

| Setting | Value |
|---------|-------|
| OS | Ubuntu (with graphical interface) |
| Instance type | `m5.large` |
| Key pair | `east1-yourname` |
| VPC | `pdl-vpc` |
| Subnet | Private-1 |
| Private IP | `10.0.8.101` |
| Volume | 30 GiB |
| IAM Instance Profile | `LabInstanceProfile` |

Assign an **Elastic IP** after launch.

---

### `dmzwin.pdl.local` — us-east-1

| Setting | Value |
|---------|-------|
| OS | Windows Server 2022 Base |
| Instance type | `m5.large` |
| Key pair | `east1-yourname` |
| VPC | `pdl-vpc` |
| Subnet | Private-2 |
| Private IP | `10.0.9.101` |
| Volume | 30 GiB |
| IAM Instance Profile | `LabInstanceProfile` |

---

### `dmzlux.pdl.local` — us-east-1

| Setting | Value |
|---------|-------|
| OS | Ubuntu |
| Instance type | `t3.small` |
| Key pair | `east1-yourname` |
| VPC | `pdl-vpc` |
| Subnet | Private-2 |
| Private IP | `10.0.9.102` |
| Volume | 30 GiB |
| IAM Instance Profile | `LabInstanceProfile` |

---

### `srv.angra.local` — us-west-2

| Setting | Value |
|---------|-------|
| OS | Amazon Linux 2023 |
| Instance type | `t3.small` |
| Key pair | Create new: `west2-yourname` |
| VPC | `angra-vpc` |
| Subnet | Public |
| Volume | 30 GiB |
| IAM Instance Profile | `LabInstanceProfile` |

**Network interfaces:**

| Interface | Subnet | IP |
|-----------|--------|----|
| Primary (eth0) | Public | `172.16.0.100` |
| Secondary (eth1) | Private-2 | `172.16.144.100` |

Allocate and associate an **Elastic IP** after launch.

---

### `intrawin.angra.local` — us-west-2

| Setting | Value |
|---------|-------|
| OS | Windows Server 2022 Base |
| Instance type | `m5.large` |
| Key pair | `west2-yourname` |
| VPC | `angra-vpc` |
| Subnet | Private-1 |
| Private IP | `172.16.128.101` |
| Volume | 30 GiB |
| IAM Instance Profile | `LabInstanceProfile` |

---

### `intralux.angra.local` — us-west-2

| Setting | Value |
|---------|-------|
| OS | Amazon Linux 2023 |
| Instance type | `t3.small` |
| Key pair | `west2-yourname` |
| VPC | `angra-vpc` |
| Subnet | Private-1 |
| Private IP | `172.16.128.102` |
| Volume | 30 GiB |
| IAM Instance Profile | `LabInstanceProfile` |

---

### `cli.angra.local` — us-west-2

| Setting | Value |
|---------|-------|
| OS | Windows Server 2022 Base |
| Instance type | `m5.large` |
| Key pair | `west2-yourname` |
| VPC | `angra-vpc` |
| Subnet | Private-2 |
| Private IP | `172.16.144.101` |
| Volume | 30 GiB |
| IAM Instance Profile | `LabInstanceProfile` |

---

## 5. Routing

Once the VPC peering connection is established and accepted, add the following routes.

### `pdl-rtb-public` (us-east-1)

| Destination | Target |
|-------------|--------|
| `172.16.128.0/20` | VPC Peering Connection |

### `pdl-rtb-private1` (us-east-1)

| Destination | Target |
|-------------|--------|
| `172.16.128.0/20` | VPC Peering Connection |

> No default route (`0.0.0.0/0`) on this table — intentional. See [Architecture Decisions](architecture-decisions.md).

### `angra-rtb-private1` (us-west-2)

| Destination | Target |
|-------------|--------|
| `10.0.8.0/24` | VPC Peering Connection |

> No default route (`0.0.0.0/0`) on this table — intentional.

Configure subnet associations for each route table to match the correct subnet.

### Troubleshooting — Connectivity Between Sites

If pings between `PRIVATE-NET-1` on each side are not working, check the following in order:

1. **VPC Peering status** — confirm the connection shows `Active` in both regions
2. **Route tables** — verify routes are present and pointing to the correct peering connection ID in both directions
3. **Security groups** — confirm both instances allow ICMP (or All Traffic) from the remote RFC1918 range
4. **IP forwarding on `srv.pdl.local`** — if traffic is routing through the NAT server, IP forwarding must be enabled:
   ```bash
   sudo sysctl -w net.ipv4.ip_forward=1
   # Make it persistent:
   echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
   sudo sysctl -p
   ```
5. **iptables on `srv.pdl.local`** — if NAT rules are interfering, check the FORWARD chain:
   ```bash
   sudo iptables -L FORWARD -v -n
   sudo iptables -t nat -L -v -n
   ```
   If needed, allow forwarding between the two private ranges explicitly:
   ```bash
   sudo iptables -I FORWARD -s 10.0.8.0/24 -d 172.16.128.0/20 -j ACCEPT
   sudo iptables -I FORWARD -s 172.16.128.0/20 -d 10.0.8.0/24 -j ACCEPT
   ```

---

## 6. Security Groups

A single shared security group is used across most instances. Create it in each VPC.

### General — All Instances

| Type | Protocol | Port | Source | Notes |
|------|----------|------|--------|-------|
| All Traffic | All | All | `10.0.0.0/8` | All RFC1918 class A |
| All Traffic | All | All | `172.16.0.0/12` | All RFC1918 class B |
| All Traffic | All | All | `YOUR_COMPETITION_IP/32` | Competition venue public IP only |

> Replace `YOUR_COMPETITION_IP` with the actual public IP of the competition venue. Never use `0.0.0.0/0`.

### RDS Security Group

| Type | Protocol | Port | Source |
|------|----------|------|--------|
| MySQL/Aurora | TCP | 3306 | `10.0.0.0/8` |
| MySQL/Aurora | TCP | 3306 | `172.16.0.0/12` |
| MySQL/Aurora | TCP | 3306 | `YOUR_COMPETITION_IP/32` |

### ASG Security Group (`web-vpc`)

Same as the general security group above but with **All Traffic** instead of MySQL-specific rules — the NLB needs to pass HTTP (80) and HTTPS (443) through.

### `srv.pdl.local` — Additional Inbound Rules

| Type | Protocol | Port | Source | Notes |
|------|----------|------|--------|-------|
| SSH | TCP | 22 | `YOUR_COMPETITION_IP/32` | Direct SSH access |
| Custom TCP | TCP | 222 | `YOUR_COMPETITION_IP/32` | SSH for `cli.pdl.local` (port-forwarded) |
| Custom TCP | TCP | 2222 | `YOUR_COMPETITION_IP/32` | SSH for `dmzlux.pdl.local` (port-forwarded) |
| RDP | TCP | 3389 | `YOUR_COMPETITION_IP/32` | RDP for `cli.pdl.local` (port-forwarded) |
| Custom TCP | TCP | 3390 | `YOUR_COMPETITION_IP/32` | RDP for `dmzwin.pdl.local` (port-forwarded) |

### `srv.angra.local` — Additional Inbound Rules

| Type | Protocol | Port | Source | Notes |
|------|----------|------|--------|-------|
| SSH | TCP | 22 | `YOUR_COMPETITION_IP/32` | Direct SSH access |
| RDP | TCP | 3389 | `YOUR_COMPETITION_IP/32` | RDP for `cli.angra.local` (port-forwarded) |
| Custom TCP | TCP | 3390 | `YOUR_COMPETITION_IP/32` | RDP for `intrawin.angra.local` (port-forwarded) |
