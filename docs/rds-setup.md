# RDS — MySQL Setup Guide
### `us-east-1` | Instance identifier: `northwind`

---

## Overview

A single RDS MySQL instance is deployed in `us-east-1` and accessed by both `cli.pdl.local` and `cli.angra.local` via MySQL Workbench. Public access is enabled so that both sites can reach it over the internet — access is restricted by the RDS security group to known IPs only.

---

## Step 1 — Create a Parameter Group

Before creating the database, create a custom parameter group so you have control over MySQL settings if needed during the competition.

**RDS → Parameter groups → Create parameter group**

| Setting | Value |
|---------|-------|
| Engine type | MySQL Community |
| Parameter group family | `mysql8.0` |
| Group name | `northwind` |
| Description | Northwind parameter group |

Create parameter group.

---

## Step 2 — Create the RDS Instance

**RDS → Databases → Create database**

| Setting | Value |
|---------|-------|
| Engine | MySQL |
| Template | Free Tier |
| DB instance identifier | `northwind` |
| Master username | `root` |
| Master password | `Passw0rd` |
| Public access | **Yes** |
| DB parameter group | `northwind` |

Leave all other settings at their defaults and create the database.

> RDS takes several minutes to provision. Launch it early and let it run in the background — see [`execution-order.md`](execution-order.md).

---

## Step 3 — Update the RDS Security Group

Once the instance is running, update its security group to allow inbound MySQL traffic from the competition environment.

**RDS → Databases → `northwind` → Connectivity & security → VPC security groups**

Add inbound rules to allow port `3306` from:

| Source | Notes |
|--------|-------|
| `10.0.0.0/8` | All RFC1918 class A (covers all pdl-vpc private ranges) |
| `172.16.0.0/12` | All RFC1918 class B (covers all angra-vpc private ranges) |
| Public IP of `srv.pdl.local` | Required for access from pdl site |
| Public IP of `srv.angra.local` | Required for access from angra site |
| Competition venue public IP | Required for direct external access |

---

## Step 4 — Load the Northwind Database

Once the RDS instance status is **Available**, connect to it and load the schema.

Get the RDS endpoint from **RDS → Databases → `northwind` → Connectivity & security → Endpoint**.

From any machine with MySQL client access:

```bash
mysql -h <RDS_ENDPOINT> -u root -p
# Enter: Passw0rd
```

Then load the Northwind schema:

```bash
mysql -h <RDS_ENDPOINT> -u root -pPassw0rd < Northwind.sql
```

The Northwind schema is available at:
`https://github.com/jdmedeiros/northwind/blob/main/Northwind.sql`

Verify the database loaded correctly:

```sql
SHOW DATABASES;
USE northwind;
SHOW TABLES;
SELECT COUNT(*) FROM Customers;
```

---

## Step 5 — Configure MySQL Workbench on Both Clients

Both `cli.pdl.local` and `cli.angra.local` must have MySQL Workbench installed and a working connection configured to the RDS instance.

**Connection settings:**

| Setting | Value |
|---------|-------|
| Connection method | Standard TCP/IP |
| Hostname | RDS endpoint (from AWS console) |
| Port | `3306` |
| Username | `root` |
| Password | `Passw0rd` |
| Default schema | `northwind` |

After configuring the connection, verify it works by running a simple query:

```sql
SELECT * FROM Customers LIMIT 10;
SELECT * FROM Orders LIMIT 10;
```

> Both clients must have a **saved, working connection** in MySQL Workbench before the Day 1 evaluation. The jury will not configure connections themselves — if the connection is missing or broken, the RDS component receives zero points.

---

## Checklist

- [ ] Parameter group `northwind` created with `mysql8.0` family
- [ ] RDS instance `northwind` provisioned and status is **Available**
- [ ] RDS security group allows port 3306 from both VPC ranges and both server public IPs
- [ ] Northwind schema loaded and tables are accessible
- [ ] MySQL Workbench configured and tested on `cli.pdl.local`
- [ ] MySQL Workbench configured and tested on `cli.angra.local`
