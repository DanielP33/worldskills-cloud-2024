# Repository Structure

```
worldskills-cloud-2024/
│
├── README.md                                     ← Start here — architecture overview and infrastructure map
│
├── diagrams/
│   ├── topology.png                              ← Full network topology diagram (competition day)
│   └── rework.jpg                                ← Revised/annotated topology
│
├── docs/                                         ← All setup guides and documentation
│   ├── architecture-decisions.md                 ← Why each design choice was made
│   ├── competition-context.md                    ← About WorldSkills and competition rules
│   ├── execution-order.md                        ← Competition day task sequence and dependencies
│   ├── creation-guide.md                         ← VPCs, peering, S3, EC2 instances, routing, security groups
│   ├── auto-scaling-group-setup.md               ← Base AMI build, ASG, step scaling, NLB
│   ├── auto-scaling-group-info.md                ← ASG reference — scaling thresholds and configuration summary
│   ├── load-balancer-setup.md                    ← NLB target groups and listeners (pdl-vpc + angra-vpc)
│   ├── route53-setup.md                          ← Private hosted zones and DNS records
│   ├── rds-setup.md                              ← RDS MySQL instance and Northwind database
│   └── website-sync-setup.md                     ← S3-based web root sync (Windows + Linux)
│
├── configs/                                      ← Actual server configuration files
│   ├── dmzlux.pdl.local-vsftpd.md               ← vsftpd config — Apache + FTP server (pdl-vpc PRIVATE-2)
│   ├── intralux.angra.local-nginx.md             ← Nginx config — intranet web server (angra-vpc PRIVATE-1)
│   ├── intralux.angra.local-vsftpd.md            ← vsftpd config — intranet FTP server (angra-vpc PRIVATE-1)
│   └── srv.angra.local-nginx.md                  ← Nginx config — public web server for www.eppv.pt
│
└── scripts/
    ├── stress-test.sh                            ← CPU load simulation for ASG scaling tests
    └── route-check.sh                            ← Connectivity matrix validation from cli.pdl.local
```

---

## Reading Order

If you're exploring this project for the first time:

1. **`README.md`** — architecture overview, infrastructure map, connectivity matrix
2. **`docs/competition-context.md`** — what the competition was and why this is impressive
3. **`docs/architecture-decisions.md`** — the thinking behind the design
4. **`diagrams/topology.png`** — visual reference for the full network
5. **`docs/execution-order.md`** — how 21 hours was planned and prioritised
6. Individual setup guides in `docs/` for each component
7. `configs/` for the actual server configuration files used
