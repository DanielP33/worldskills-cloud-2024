# Architecture Decisions

This document explains the reasoning behind key design choices made during the competition.

---

## 1. VPC Peering vs Transit Gateway

The competition allowed either a VPC Peering Connection or a Transit Gateway for cross-region connectivity between `pdl-vpc` and `angra-vpc`. The choice was selected at random by the judges on competition day to test competitors' ability to adapt on the spot.

**Trade-offs:**
- **VPC Peering** is simpler, lower cost, lower latency — suitable for two-site connectivity
- **Transit Gateway** scales better for hub-and-spoke topologies with many VPCs, but adds cost and complexity

For two sites with a single peering requirement, VPC Peering is the right call. Transit Gateway would be the choice if a third site (e.g. `web-vpc`) needed to participate in the private routing.

---

## 2. No Default Routes on PRIVATE-NET-1

The routing tables for `PRIVATE-NET-1` on both `pdl-vpc` and `angra-vpc` deliberately have **no default route (0.0.0.0/0)**.

This was a hard competition requirement, but it's also correct security practice:
- Internal servers in PRIVATE-NET-1 have no direct internet exposure
- The only allowed traffic is the explicitly scoped peering route
- Internet access for these machines is not needed — they serve internal workloads only

Any default route in these tables would have resulted in zero points for all cross-region criteria — and would also represent a real security misconfiguration in production.

---

## 3. EFS for Auto Scaling Web Root

The web root for `www.nacional.pt` is served from an **EFS filesystem**, mounted read-only on each ASG instance.

**Why EFS instead of baking content into the AMI or using S3:**
- ASG instances can scale in/out dynamically — EFS ensures all instances always serve identical content
- Read-only mount prevents any single compromised or misconfigured instance from modifying shared content
- Content updates only need to happen once (on the EFS mount), propagating instantly to all instances
- S3 + sync would introduce lag; EFS is a true shared filesystem

---

## 4. Step Scaling vs Target Tracking

A **step scaling policy** was used for the Auto Scaling Group rather than target tracking.

The competition specified exact thresholds (CPU < 50 → 1 instance, 50–75 → 2, ≥75 → 3) which map directly to step scaling. Target tracking aims for a target value and manages scaling automatically — it wouldn't give the precise, deterministic behaviour required here.

Step scaling also makes the scale-in logic explicit: the same CPU thresholds apply in reverse, with the last-added instance being the first removed.

---

## 5. Two Separate NLBs for www.enta.pt

A **public NLB** and a **private NLB** were configured pointing to the same backend (`dmzwin.pdl.local` + `dmzlux.pdl.local`).

**Why two NLBs:**
- `cli.angra.local` (in another region) and internet users access via the **public NLB**
- `cli.pdl.local` (internal to `pdl-vpc`) accesses via the **private NLB**
- This avoids hairpinning internal traffic through the public internet
- It also allows different security group rules and access controls per audience

---

## 6. Certificate Authority on srv.pdl.local

Rather than using self-signed certificates per-server, a **central CA** was installed on `srv.pdl.local` and used to issue all certificates across the infrastructure.

**Benefits:**
- Single trust anchor — installing the CA cert on clients validates all issued certificates
- Consistent certificate parameters across the entire environment
- Realistic enterprise pattern — matches how internal PKI works in production

Certificates were not password-protected to allow automated service restarts without manual intervention.

---

## 7. Security Group Design

All security groups follow a default-deny posture with explicit allow rules only:

- No `0.0.0.0/0` ingress except from the competition's specific public IP
- RFC1918 blocks (`10.0.0.0/8`, `172.16.0.0/12`) treated as trusted for internal traffic
- `srv.pdl.local` and `srv.angra.local` act as SSH/RDP jump hosts — single public IP exposure point per site

The competition required only the minimum necessary security group configuration. However, I chose to go further and harden both the security groups and the Windows Firewall rules beyond what was required, applying a strict least-privilege approach — allowing only the specific protocols, ports, and sources needed for each service (FTP, HTTP, HTTPS, RDP, SSH). This did not contribute additional points to the score, but it was a deliberate personal challenge to apply production-grade security practices within a competition environment.

---

## 8. S3 as File Sync Intermediary

Rather than syncing web roots directly between paired servers (Windows ↔ Linux), **S3 is used as a shared intermediary**:

```
dmzwin  ──► S3 bucket ──► dmzlux
dmzlux  ──► S3 bucket ──► dmzwin
```

**Why S3 instead of direct sync (rsync, SCP):**
- Avoids direct server-to-server SSH access between PRIVATE-2 machines
- S3 is highly available and durable — no dependency on either server being up
- The same pattern works identically for both site pairs (`pdl` and `angra`) without additional network configuration
- Decouples the two servers: either can be restarted independently without breaking sync
