# Competition Day — Execution Order
### Dependency-driven task sequence for a 21-hour deployment window

---

## Why order matters

This infrastructure has hard dependencies — you cannot configure HTTPS on any server before the CA exists, cannot test cross-region connectivity before routing is configured, and cannot evaluate the ASG before the base AMI is built. Getting the order wrong costs time you don't have.

The sequence below is optimised for two things: unblocking parallel work as early as possible, and hitting the **Day 1 evaluation deadline** (Auto Scaling Group, S3 notifications, RDS) with time to spare.

---

## Day 1 Priority — Must be complete before 17:30

The jury evaluates three components at the end of Day 1:
1. Auto Scaling Group (`www.nacional.pt`)
2. S3 bucket — upload notification via SNS email
3. RDS MySQL — both clients connected to Northwind database

Everything else is evaluated after Day 3. Plan accordingly.

---

## Execution Order

### Phase 1 — Foundation (do this first, everything else depends on it)

**1. Create all three VPCs**
- `pdl-vpc` (us-east-1), `web-vpc` (us-east-1), `angra-vpc` (us-west-2)
- Subnets, route tables, and S3 gateway endpoints are created by the wizard
- See [`docs/creation-guide.md`](creation-guide.md)

**2. Configure cross-region connectivity**

- Establish VPC Peering Connection between `pdl-vpc` and `angra-vpc`
- Add routes to `pdl-rtb-private1` and `angra-rtb-private1`
- No default routes on either private route table
- Verify peering status is `Active` in both regions before moving on

**3. Launch `srv.pdl.local`**
- This is the NAT server, SSH/RDP jump host, and — critically — the **Certificate Authority**
- Nothing that requires HTTPS can be configured until this machine is up and the CA is installed
- Assign Elastic IP immediately after launch
- Install and configure Easy-RSA, then issue certificates for all domains before touching any web server

> **Certificates to issue before moving to Phase 2:**
> `www.enta.pt`, `www.nacional.pt`, `intranet.angra.local`, `www.eppv.pt`
> and any individual server hostnames that need them.

**4. Launch `srv.angra.local`**
- NAT server and jump host for the Angra site
- Assign Elastic IP immediately after launch
- Configure NAT and routing for `angra-vpc` private subnets

---

### Phase 2 — Day 1 Deadline targets (start as early as possible)

**5. Create the S3 bucket and SNS notification**
- Quick to configure, easy to forget under pressure
- Do this early — the SNS email subscription confirmation takes a few minutes to arrive
- Test with a file upload before moving on
- See [`creation-guide.md`](creation-guide.md)

**6. Launch `dmzwin.pdl.local` and `dmzlux.pdl.local`**
- These are the backend targets for `lb-private` and `lb-public`
- Install IIS (Windows) and Apache (Linux), configure HTTP and HTTPS with certificates from `srv.pdl.local`
- Copy web content from GitHub
- Configure FTP on both servers
- Set up file sync between the two web roots (max 5-minute lag)

**7. Create target groups and load balancers for `pdl-vpc`**
- `port80-private`, `port443-private`, `port80-public`, `port443-public`
- `lb-private` (internal) and `lb-public` (internet-facing)
- Import certificates into the TLS listeners
- See [`load-balancer-setup.md`](load-balancer-setup.md)

**8. Configure RDS — MySQL**
- Launch RDS instance (`Northwind` identifier) in `us-east-1`
- Load the Northwind database schema
- This takes several minutes to provision — launch it and let it run in the background while you work on other things
- Do not wait for it to finish before moving on

**9. Build the ASG base image**
- Launch the `Base` EC2 instance in `web-vpc`
- Mount EFS at `/var/www/html`
- Install Apache, PHP, stress-ng
- Copy certificates from `srv.pdl.local`
- Configure SSL in Apache
- Copy web content from GitHub
- Shut down and create AMI (`base-image`)
- See [`auto-scaling-group-setup.md`](auto-scaling-group-setup.md)

**10. Create the Auto Scaling Group**
- Create launch template from `base-image`
- Create ASG with step scaling policies (ScaleOut + ScaleIn)
- Attach to NLB in `web-vpc`
- Configure termination policy: Newest Instance, 60s cooldown
- **Enable detailed CloudWatch monitoring** — without this, scaling reacts on 5-minute intervals instead of 1-minute

**11. Verify Day 1 evaluation components**

Before 17:00 (leave a buffer):

- [ ] Hit `https://www.nacional.pt` — page loads, certificate valid, HTTP redirects to HTTPS
- [ ] Run `stress-ng` on an ASG instance — verify CloudWatch metrics update and instances scale out
- [ ] Upload a file to S3 — confirm email arrives at `medeiros@enta.pt`
- [ ] Connect MySQL Workbench on both clients to RDS — run a query against Northwind
- [ ] Confirm `stress-ng` is installed on the AMI (jury will test this)

---

### Phase 3 — Remaining infrastructure (Days 2–3)

**12. Launch `cli.pdl.local`**
- Install Chromium, Wireshark, FileZilla, MySQL Workbench
- Configure MySQL Workbench connection to RDS
- Configure FileZilla connections to all FTP servers
- Verify all connectivity tests (positive and negative)

**13. Launch `intrawin.angra.local` and `intralux.angra.local`**
- Configure IIS (Windows) and Nginx (Linux) for HTTP and HTTPS
- Copy certificates from `srv.pdl.local`
- Copy web content from GitHub
- Configure FTP on both servers
- Set up file sync between the two web roots (max 5-minute lag)

**14. Create target groups and load balancer for `angra-vpc`**
- `port80-private`, `port443-private`
- `lb-private` (internal) in `angra-subnet-private1`
- Import `intranet.angra.local` certificate into the TLS listener

**15. Configure Route 53**
- Create private hosted zones in both regions
- A records for all EC2 instances and servers
- CNAME records for all load balancers
- Verify DNS resolution from both clients — no `/etc/hosts` entries

**16. Launch `cli.angra.local`**
- Install Chrome and Wireshark
- Configure MySQL Workbench connection to RDS
- Verify all connectivity tests (positive and negative)
- Verify access to `www.eppv.pt`, `intranet.angra.local`, and `www.enta.pt` via public NLB

**17. Configure port forwarding on `srv.pdl.local` and `srv.angra.local`**
- SSH and RDP port forwarding for all private machines
- Verify external access on all required ports
- See security group port table in [`creation-guide.md`](creation-guide.md)

**18. Final pre-evaluation checks**

- [ ] All web servers reachable by correct hostname from correct client
- [ ] HTTP → HTTPS redirect working everywhere required
- [ ] All certificates valid (except `https://intranet.angra.local/info.php`)
- [ ] FTP accessible with and without TLS from `cli.pdl.local`
- [ ] File sync working between paired servers (test by creating a file on one, verify it appears on the other within 5 minutes)
- [ ] Positive and negative connectivity tests passing from both clients
- [ ] Route 53 resolving all names correctly — no `/etc/hosts` entries anywhere
- [ ] Private keys stored in S3 bucket, clearly labelled (`east1-yourname`, `west2-yourname`)
- [ ] `LabInstanceProfile` applied to every EC2 instance

---

## Dependency Map

```
VPCs + Peering
    └── srv.pdl.local (CA)
            ├── Certificates → all HTTPS servers
            ├── dmzwin.pdl.local + dmzlux.pdl.local
            │       └── lb-private + lb-public (pdl-vpc)
            │               └── www.enta.pt
            ├── ASG base image → Auto Scaling Group
            │       └── www.nacional.pt
            └── intrawin.angra.local + intralux.angra.local
                    └── lb-private (angra-vpc)
                            └── intranet.angra.local

    └── srv.angra.local (NAT)
            └── Private subnet routing (angra-vpc)

RDS (launch early, runs in background)
    └── cli.pdl.local + cli.angra.local (MySQL Workbench)

S3 + SNS (quick, do early)
```
