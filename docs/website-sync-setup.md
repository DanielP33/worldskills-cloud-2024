# Website Root Sync — Setup Guide
### `dmzwin.pdl.local` ↔ `dmzlux.pdl.local` via S3

---

## Overview

The web roots of `dmzwin.pdl.local` (Windows/IIS) and `dmzlux.pdl.local` (Linux/Apache) must stay in sync with a maximum lag of 5 minutes. Rather than syncing directly between the two machines, **S3 is used as an intermediary**:

```
dmzwin  ──► S3 bucket ──► dmzlux
dmzlux  ──► S3 bucket ──► dmzwin
```

Each machine runs a sync script on a schedule — pushing its local changes to S3 and pulling any changes from S3. This means either machine can be updated and the other will reflect those changes within one cron/task cycle.

Two S3 buckets are used — one per web root (HTTP and HTTPS roots are kept separate).

---

## Prerequisites

Both machines need AWS CLI configured with credentials that have read/write access to the S3 buckets.

> **Security note:** Use IAM credentials scoped to only the required S3 buckets. Never commit real credentials to a repository. In the competition environment, temporary lab credentials were used and have since expired.

---

## Windows — `dmzwin.pdl.local`

### 1. Install AWS CLI

Run in CMD as Administrator:

```cmd
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
```

### 2. Configure AWS CLI

```cmd
aws configure
```

Enter your credentials when prompted:

```
AWS Access Key ID [None]: YOUR_ACCESS_KEY_ID
AWS Secret Access Key [None]: YOUR_SECRET_ACCESS_KEY
Default region name [None]: us-east-1
Default output format [None]: json
```

Alternatively, edit the credentials file directly:

```
C:\Users\Administrator\.aws\credentials
```

### 3. Create the sync script

Create a file on the Desktop called `sync-websites.ps1`:

```powershell
# Sync HTTP web root
$localPath = "C:\inetpub\wwwroot"
$s3Path    = "s3://your-http-bucket"
aws s3 sync $localPath $s3Path
aws s3 sync $s3Path $localPath

# Sync HTTPS web root
$localPath = "C:\inetpub\wwwroots"
$s3Path    = "s3://your-https-bucket"
aws s3 sync $localPath $s3Path
aws s3 sync $s3Path $localPath
```

Replace `your-http-bucket` and `your-https-bucket` with your actual S3 bucket names.

### 4. Schedule the script

Open **Task Scheduler** and create a new task:

| Setting | Value |
|---------|-------|
| Trigger | Every 3 minutes, indefinitely |
| Action | `powershell.exe -ExecutionPolicy Bypass -File "C:\Users\Administrator\Desktop\sync-websites.ps1"` |
| Run as | Administrator |
| Run whether user is logged on or not | Yes |

---

## Linux — `dmzlux.pdl.local`

### 1. Install AWS CLI

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### 2. Configure AWS CLI

```bash
aws configure
```

Enter your credentials when prompted. The credentials file is stored at:

```bash
~/.aws/credentials
# or for root:
/root/.aws/credentials
```

To edit directly:

```bash
sudo su
find / -name ".aws" 2>/dev/null
cd ~/.aws
nano credentials
```

### 3. Create the sync script

```bash
sudo nano /usr/local/bin/sync-websites
```

Paste the following:

```bash
#!/bin/bash

logger "Syncing web site roots..."

# HTTP web root
localPath1="/var/www/html"
s3Path1="s3://your-http-bucket"

# HTTPS web root
localPath2="/var/www/htmls"
s3Path2="s3://your-https-bucket"

# Push local changes to S3, then pull S3 changes to local
aws s3 sync "$localPath1" "$s3Path1"
aws s3 sync "$s3Path1" "$localPath1"

aws s3 sync "$localPath2" "$s3Path2"
aws s3 sync "$s3Path2" "$localPath2"
```

Replace `your-http-bucket` and `your-https-bucket` with your actual S3 bucket names.

### 4. Make the script executable

```bash
chmod +x /usr/local/bin/sync-websites
```

### 5. Schedule with cron

```bash
crontab -e
```

Add the following line:

```
*/3 * * * * /usr/local/bin/sync-websites
```

This runs the sync every 3 minutes, well within the 5-minute maximum lag requirement.

---

## Verify

To test manually before relying on the schedule:

```bash
# Linux
/usr/local/bin/sync-websites

# Windows (PowerShell)
& "C:\Users\Administrator\Desktop\sync-websites.ps1"
```

Create a test file on one machine and verify it appears on the other within 3 minutes. Check `/var/log/syslog` on Linux for the `logger` output to confirm the script is running on schedule.
