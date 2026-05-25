# Auto Scaling Group — Setup Guide
### `web-vpc` | `us-east-1` | `www.nacional.pt`

This guide walks through building the base AMI, configuring the Auto Scaling Group with step scaling, and validating the setup end-to-end.

---

## Overview

The approach is:
1. Launch a **base EC2 instance** — install and configure everything (Apache, PHP, SSL, EFS, stress-ng)
2. Create an **AMI** from that instance
3. Use that AMI in a **Launch Template** for the Auto Scaling Group
4. Configure **step scaling policies** with CloudWatch alarms
5. Configure the **Network Load Balancer** with HTTP → HTTPS redirect

---

## Step 1 — Create the Base Instance

### Launch Instance

| Setting | Value |
|---------|-------|
| Name | `Base` |
| OS | Ubuntu 24 |
| Instance Type | `m5.large` |
| Key Pair | Your competition key pair |
| VPC | `web-vpc` |
| Subnet | `web-subnet-public-1` |
| Security Group | VPC default (edit to allow **All Traffic**) |
| IAM Instance Profile | `LabInstanceProfile` ← apply to every machine |
| Detailed CloudWatch Monitoring | **Enabled** |

### Attach EFS at Launch

In **Storage → Edit → File Systems → EFS**, create a new file system:

- Name: `nacional`

> After launch, you'll need to add mount targets for the remaining subnets (see Step 2).

Launch the instance.

---

## Step 2 — Configure EFS Mount Targets

Go to **EFS → `nacional` → Network → Manage**.

Add a mount target for each of the remaining `web-vpc` subnets (the launch wizard only covers one). Use the same security groups for all mount targets.

Save.

---

## Step 3 — Configure the Base Instance

Assign an **Elastic IP** to the base instance and connect via SSH.

### Fix the EFS Mount Point

By default, EFS mounts to `/mnt/efs/fs1`. You need it at `/var/www/html` instead.

Verify the current mount:
```bash
df -h
# You should see something like:
# fs-04e1eab1af9b790ec.efs.us-east-1.amazonaws.com:/ /mnt/efs/fs1
```

Edit `/etc/fstab` and change `/mnt/efs/fs1` to `/var/www/html`:
```bash
sudo nano /etc/fstab
```

Apply and verify:
```bash
sudo mount -a
sudo systemctl daemon-reload
df -h
# /var/www/html should now appear in the output
```

### Install Apache, PHP, and stress-ng

```bash
sudo apt update -y && sudo apt upgrade -y
sudo apt install apache2 -y
sudo a2enmod ssl
sudo a2ensite default-ssl.conf

# PHP (check available version first)
sudo apt search php | grep libapache2-mod-php
sudo apt install libapache2-mod-php8.3 -y

# stress-ng (required for ASG evaluation)
sudo add-apt-repository ppa:colin-king/stress-ng -y
sudo apt install stress-ng -y
```

### Deploy Web Content

```bash
sudo su
umount /mnt/efs/fs1   # unmount old path if still present
mount -a
df -h                 # confirm /var/www/html is mounted

cd /var/www/html
git clone https://github.com/jdmedeiros/cc2024
cd cc2024
cp -r * ..
cd ..
rm -rf cc2024/
```

> Customise the page files where applicable before copying.

### Install SSL Certificate

From **`srv.pdl.local`**, copy the certificate and key to the base instance.

On `srv.pdl.local`:
```bash
sudo su -

# Place your ASG key pair
nano ASG.pem
chmod 400 ASG.pem

# Copy certificate
sudo scp -i ASG.pem /etc/easy-rsa/pki/issued/www.nacional.pt.crt \
  ubuntu@<BASE_INSTANCE_IP>:/tmp/www.nacional.pt.crt
ssh -i ASG.pem ubuntu@<BASE_INSTANCE_IP> \
  'sudo mv /tmp/www.nacional.pt.crt /etc/ssl/certs/'

# Copy private key
sudo scp -i ASG.pem /etc/easy-rsa/pki/private/www.nacional.pt.key \
  ubuntu@<BASE_INSTANCE_IP>:/tmp/www.nacional.pt.key
ssh -i ASG.pem ubuntu@<BASE_INSTANCE_IP> \
  'sudo mv /tmp/www.nacional.pt.key /etc/ssl/private/'
```

Back on the **base instance**, point Apache's SSL config to the certificate:
```bash
sudo nano /etc/apache2/sites-available/default-ssl.conf
```

Update these two lines:
```apache
SSLCertificateFile      /etc/ssl/certs/www.nacional.pt.crt
SSLCertificateKeyFile   /etc/ssl/private/www.nacional.pt.key
```

Restart Apache and verify everything works:
```bash
sudo systemctl restart apache2
```

### Shut Down the Base Instance

```bash
sudo shutdown now
```

> The instance must be stopped before creating an AMI to ensure a consistent disk snapshot.

---

## Step 4 — Create the Base AMI

In the EC2 console:

**Instances → `Base` → Actions → Image and Templates → Create Image**

| Setting | Value |
|---------|-------|
| Image name | `base-image` |

Create image. Wait for the AMI status to become **Available** before proceeding.

---

## Step 5 — Create the Launch Template

**EC2 → Launch Templates → Create Launch Template**

| Setting | Value |
|---------|-------|
| Name | `launch-template` |
| AMI | Your `base-image` (under **My AMIs**) |
| Instance Type | `m5.large` |
| Key Pair | Your competition key pair |
| IAM Instance Profile | `LabInstanceProfile` |
| Detailed CloudWatch Monitoring | **Enabled** |

Create launch template.

---

## Step 6 — Create the Auto Scaling Group

**EC2 → Auto Scaling Groups → Create Auto Scaling Group**

| Setting | Value |
|---------|-------|
| Name | `asg` |
| Launch Template | `launch-template` |

**Network:**
| Setting | Value |
|---------|-------|
| VPC | `web-vpc` |
| Availability Zones | All three |

**Load Balancer:**
| Setting | Value |
|---------|-------|
| Attach to | New load balancer |
| Scheme | Internet-facing |
| Default routing | Create target group — name: `asg-lb-tg-http` |

**Capacity:**
| Setting | Value |
|---------|-------|
| Desired | 1 |
| Minimum | 1 |
| Maximum | 3 |

Continue through to **Review** and create.

---

## Step 7 — Configure the Load Balancer

### Redirect HTTP → HTTPS

**EC2 → Load Balancers → your LB → Listeners**

Edit the **HTTP :80** listener:
- Action: **Redirect to URL**
- Port: `443`

Save.

### Add HTTPS Listener

Add a new listener:
- Protocol: `HTTPS`
- Target Group: `asg-lb-tg-http`
- Certificate: **Import**

Retrieve the certificate and key from `srv.pdl.local`:
```bash
# Private key
sudo cat /etc/easy-rsa/pki/private/www.nacional.pt.key

# Certificate body
sudo cat /etc/easy-rsa/pki/issued/www.nacional.pt.crt
```

Paste each into the corresponding field and add the listener.

---

## Step 8 — Create CloudWatch Alarms

You need two alarms — one for scale-out, one for scale-in.

### Alarm 1 — Scale-Out trigger (CPU ≥ 50%)

**CloudWatch → Alarms → Create Alarm → Select Metric**

- Metric: `EC2 → Auto Scaling Group → CPUUtilization`
- Statistic: Average
- Period: 1 minute
- Condition: **Greater/Equal than 50**
- Notification: Remove (not needed)
- Name: `CPUUTILIZATION_GT50`

### Alarm 2 — Scale-In trigger (CPU < 75%)

- Metric: `EC2 → Auto Scaling Group → CPUUtilization`
- Statistic: Average
- Period: 1 minute
- Condition: **Lower than 75**
- Name: `CPUUTILIZATION_LT75`

---

## Step 9 — Create Step Scaling Policies

**Auto Scaling Group → `asg` → Automatic Scaling → Create Dynamic Scaling Policy**

### Scale-Out Policy

| Setting | Value |
|---------|-------|
| Policy type | Step scaling |
| Name | `ScaleOut` |
| CloudWatch alarm | `CPUUTILIZATION_GT50` |
| Instance warmup | 60 seconds |

Steps:
| Condition | Action |
|-----------|--------|
| 50 ≤ CPUUtilization < 75 | Set to **2** capacity units |
| 75 ≤ CPUUtilization < +∞ | Set to **3** capacity units |

### Scale-In Policy

| Setting | Value |
|---------|-------|
| Policy type | Step scaling |
| Name | `ScaleIn` |
| CloudWatch alarm | `CPUUTILIZATION_LT75` |
| Instance warmup | 60 seconds |

Steps:
| Condition | Action |
|-----------|--------|
| 49 < CPUUtilization ≤ 75 | Set to **2** capacity units |
| −∞ < CPUUtilization ≤ 49 | Set to **1** capacity unit |

---

## Step 10 — Configure Instance Termination Policy

**Auto Scaling Group → `asg` → Details → Edit**

Find **Termination policies**:
- Policy: **Newest Instance**
- Default instance warmup / cooldown: **60 seconds**

This ensures the most recently launched instance is always the first to be terminated on scale-in.

---

## Step 11 — Validate

Start the **base instance** and SSH in to run load tests.

### Simulate CPU load
```bash
# ~75% load — should trigger scale-out to 2 instances
stress-ng -c 0 -l 75 --aggressive

# Adjust the load value to test each threshold
```

### HTTP load test
```bash
ab -c 100 -n 500 -r http://<LOAD_BALANCER_DNS>/
```

### Verify in browser

Copy the **NLB DNS name** from the EC2 console and open it:
```
http://asg-lb-xxxxxxxxxxxxxxx.us-east-1.elb.amazonaws.com
```

You should be automatically redirected to HTTPS and see the `www.nacional.pt` page.

Monitor scaling activity under:
**CloudWatch → EC2 → Auto Scaling Group → CPUUtilization**

Expect scale-out within ~2 minutes (1-minute CloudWatch metric + 60s warmup).

---

## Checklist

- [ ] EFS mounted at `/var/www/html` (not `/mnt/efs/fs1`)
- [ ] Apache serving content over HTTP and HTTPS
- [ ] HTTP → HTTPS redirect working on the NLB
- [ ] SSL certificate valid (`www.nacional.pt.crt` from internal CA)
- [ ] PHP working (`/info.php` returns PHP info page)
- [ ] `stress-ng` installed and executable on the AMI
- [ ] Step scaling policies created (ScaleOut + ScaleIn)
- [ ] Termination policy set to **Newest Instance**
- [ ] Warmup and cooldown set to **60 seconds**
- [ ] ASG scales 1 → 2 → 3 and back under load
