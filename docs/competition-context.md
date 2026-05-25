# Competition Context

## WorldSkills Portugal — Skill 53: Cloud Computing

WorldSkills is the global vocational skills competition, often called the "Olympics of skills." Portugal participates through **IEFP** (Instituto do Emprego e Formação Profissional), which is a founding member of both WorldSkills International and WorldSkills Europe.

### About the Competition

- **Event:** WorldSkills Portugal 2024 — National Championship
- **Skill:** 53 — Cloud Computing
- **Dates:** November 13–15, 2024
- **Duration:** 21 hours total (3 × 7-hour days)
- **Result:** 🥇 1st place — National Champion (Regional Gold + National Gold)

### Competition Rules Relevant to This Project

1. **Functionality-only scoring** — no partial credit for configuration that doesn't produce working results
2. **No external assistance** — no help from coaches, other competitors, or the assigned judge during competition hours
3. **Restricted AMIs** — only Quick Start AMIs permitted; version choice was free unless specified
4. **IP-restricted access** — the AWS environment was only accessible from the competition venue's public IP
5. **Key pair management** — private keys stored in S3, clearly labelled, required for judge evaluation
6. **Real-time evaluation** — Auto Scaling Group, S3 notifications, and RDS access were evaluated live at end of Day 1; all other components evaluated after Day 3

### What This Demonstrates

Building this infrastructure in 21 hours under competition conditions required:

- Knowing AWS services well enough to work without documentation lookups for core configuration
- Prioritising tasks correctly — components evaluated on Day 1 had to be complete by end of Day 1
- Debugging under pressure — no external help, no second chances on evaluated components
- Thinking in systems — each component depended on others (e.g., ASG evaluation required stress-ng pre-installed, NAT working, EFS mounted, HTTPS configured)

The same infrastructure built at a normal pace in a professional context would typically take several days of planning and implementation. The competition constraint tests applied knowledge, not the ability to look things up.
