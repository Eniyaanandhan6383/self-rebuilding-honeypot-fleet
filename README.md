# Self-Rebuilding Honeypot Fleet

A fleet of containerized SSH honeypots (Cowrie) running in a locked-down AWS VPC with **no outbound internet access**. The honeypots are destroyed and rebuilt automatically with a new identity (hostname and SSH banner), so attackers cannot fingerprint them, and a compromised honeypot cannot be used as a launch pad for real attacks.

> **Status:** work in progress. Core structure and infrastructure code are in place; testing and some automation are still being completed (see [Current Status](#current-status)).

---

## Table of Contents
1. [Problem Statement](#problem-statement)
2. [Solution Overview](#solution-overview)
3. [Architecture](#architecture)
4. [Key Features](#key-features)
5. [Tech Stack](#tech-stack)
6. [Why Each Tool Is Needed](#why-each-tool-is-needed)
7. [Repository Structure](#repository-structure)
8. [Prerequisites](#prerequisites)
9. [Deployment Guide](#deployment-guide)
10. [How Rotation Works](#how-rotation-works)
11. [Isolation Test](#isolation-test)
12. [Dashboard](#dashboard)
13. [Cost Notes](#cost-notes)
14. [Security and Safety](#security-and-safety)
15. [Current Status](#current-status)
16. [Limitations](#limitations)
17. [Future Work](#future-work)
18. [Team](#team)

---

## Problem Statement

Honeypots are fake systems that attract attackers so their behaviour can be studied. Two problems make them less useful in practice:

1. **Fingerprinting.** A honeypot that stays unchanged for weeks gets identified by attackers and automated scanners, and is then ignored.
2. **Compromise risk.** A compromised honeypot can become a launch pad for attacks on real systems.

Existing projects such as T-Pot are usually set up once by hand and left running. Automated rotation combined with an automated isolation check is the gap this project addresses.

---

## Solution Overview

1. A Cowrie SSH honeypot runs in a Docker container on **AWS Fargate** inside a **private subnet with no internet route**.
2. Attackers reach the honeypot through a **Network Load Balancer** (port 22 forwarded to container port 2222). The honeypot itself never needs a public IP.
3. Attacker activity is written as JSON logs to **CloudWatch Logs** and visualised on a **CloudWatch dashboard**.
4. A **weekly GitHub Actions pipeline** generates a new random persona (hostname and SSH banner), runs a static security scan, and redeploys the fleet with **Terraform**.
5. An isolation test confirms the honeypot network still cannot reach the internet.
6. A **Lambda function** can force a rebuild when a CloudWatch alarm detects suspicious activity.

---

## Architecture

```
                 Internet (attackers)
                         |
                  port 22 (SSH)
                         |
            +------------v------------+
            |  Network Load Balancer  |   <- public subnet (only the NLB lives here)
            +------------+------------+
                         |
                  port 2222 (TCP)
                         |
            +------------v------------+
            |  ECS Fargate tasks      |   <- private subnet, NO NAT, NO internet route
            |  (Cowrie honeypots)     |
            +------------+------------+
                         |  (only HTTPS to VPC endpoints)
        +----------------+-----------------+
        |                |                 |
   ECR endpoints    CloudWatch Logs     S3 gateway
 (pull image)       endpoint (logs)     endpoint (image layers)
                         |
                CloudWatch Dashboard
```

**Rotation flow**

```
GitHub Actions (weekly)  --->  generate_persona.py  --->  terraform apply
                                                              |
                                           new task definition (new hostname/banner)
                                                              |
                                           ECS replaces old honeypots with new ones
                                                              |
                                                 isolation test must pass

CloudWatch alarm (suspicious activity) ---> Lambda ---> ECS force-new-deployment
```

---

## Key Features

- **Disposable honeypots:** any honeypot can be destroyed and recreated in a clean state.
- **Automatic identity rotation:** new hostname and SSH version banner on every rebuild.
- **No outbound internet:** the honeypot subnet has no NAT gateway and no internet gateway route. The security group allows only HTTPS to the VPC endpoints and the S3 prefix list.
- **Infrastructure as Code:** the entire environment is created and destroyed with Terraform.
- **Automated pipeline:** scheduled rebuilds with a static security scan.
- **Event-based rotation:** an alarm-triggered Lambda can replace the fleet on demand.
- **Visibility:** dashboard showing top attacker IPs, usernames tried and commands run.

---

## Tech Stack

| Area | Tool |
|------|------|
| Honeypot | Cowrie (SSH honeypot) |
| Containers | Docker |
| Cloud | AWS: VPC, VPC endpoints, ECS Fargate, ECR, NLB, CloudWatch, Lambda, IAM |
| Infrastructure as Code | Terraform |
| CI/CD | GitHub Actions |
| Security scanning | Checkov |
| Scripting | Python 3, Bash |

---

## Why Each Tool Is Needed

- **Docker:** honeypots must be disposable and reset to a clean state instantly.
- **Terraform:** network isolation and every rotation are infrastructure operations. Safe teardown and recreation is the core feature of the project.
- **Pipeline:** rebuilds the fleet weekly with a new identity and checks that isolation still holds before anything is exposed.

---

## Repository Structure

``
self-rebuilding-honeypot-fleet/
├── README.md
├── .gitignore
├── docs/
│   ├── problem-statement.md
│   └── demo-screenshots/
├── honeypot/
│   ├── Dockerfile                  # Cowrie image with default persona
│   └── config/
│       └── cowrie.cfg              # JSON logging config
├── terraform/
│   ├── main.tf                     # Provider and ECR repository
│   ├── variables.tf                # Region, hostname, SSH banner, task count
│   ├── vpc.tf                      # Public/private subnets, VPC endpoints
│   ├── ecs.tf                      # Cluster, task definition, service, security groups, IAM
│   ├── nlb.tf                      # Network Load Balancer, target group, listener
│   ├── logging.tf                  # CloudWatch dashboard
│   ├── rotation.tf                 # Alarm-based rotation (TODO)
│   └── outputs.tf                  # NLB DNS name, ECR URL, subnet, security group
├── scripts/
│   └── generate_persona.py         # Generates new hostname/banner for each rebuild
├── lambda/
│   └── rotate_on_alert.py          # Forces ECS redeploy on alarm
├── tests/
│   └── isolation_test/
│       ├── Dockerfile
│       ├── test_egress.py          # Fails if the internet is reachable
│       └── run_test.sh             # Runs the test inside the honeypot network
└── .github/
    └── workflows/
        └── rebuild.yml             # Weekly rebuild pipeline
```

---

## Prerequisites

1. A **separate or isolated AWS account** (do not run next to real workloads).
2. AWS CLI configured with credentials for that account.
3. Terraform 1.5 or newer.
4. Docker.
5. Python 3.
6. A budget alarm set on the AWS account.

---

## Deployment Guide

Run all commands from the repository root unless stated otherwise.

1. **Initialise Terraform**
```bash
   cd terraform
   terraform init
```

2. **Create the ECR repository first** (the image must exist before the service starts)
```bash
   terraform apply -target=aws_ecr_repository.honeypot
```

3. **Build and push the honeypot image**
```bash
   ECR=$(terraform output -raw ecr_repository_url)
   aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR%%/*}
   docker build -t $ECR:latest ../honeypot
   docker push $ECR:latest
```

4. **Generate a persona** (from the repository root)
```bash
   cd ..
   python scripts/generate_persona.py
```

5. **Deploy everything**
```bash
   cd terraform
   terraform apply
```

6. **Test the honeypot**
```bash
   terraform output nlb_dns_name
   ssh root@<nlb_dns_name>
```
   Try logging in with any password and run a few commands. The events should appear in CloudWatch.

7. **Clean up after the demo**
```bash
   terraform destroy
```

### GitHub Actions secrets
For the weekly pipeline, add these in **Settings > Secrets and variables > Actions**:

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key for the isolated account |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |

Never commit credentials to the repository.

---

## How Rotation Works

**Scheduled rotation (weekly)**
1. GitHub Actions starts on a cron schedule (Monday 02:00 UTC) or manually via `workflow_dispatch`.
2. `scripts/generate_persona.py` picks a random hostname and SSH version banner and writes `terraform/persona.auto.tfvars.json`.
3. Checkov scans the Terraform code.
4. The image is rebuilt and pushed to ECR.
5. `terraform apply` creates a new task definition with the new persona, and ECS replaces the running honeypots.

**Event-based rotation**
1. A CloudWatch metric filter watches for suspicious Cowrie events (for example file downloads).
2. An alarm fires when a threshold is crossed.
3. The alarm triggers `lambda/rotate_on_alert.py`, which calls ECS `UpdateService` with `forceNewDeployment`.

---

## Isolation Test

The most important safety check in the project: **the honeypot network must not be able to reach the internet.**

Two layers:

1. **Static check:** Checkov scans the Terraform code for unsafe network rules.
2. **Runtime check:** `tests/isolation_test/run_test.sh` launches a one-off Fargate task in the **same subnet and security group** as the honeypots. The task (`test_egress.py`) tries to open `https://example.com` and `https://1.1.1.1`.
   - If it **cannot** connect: exit code 0, **PASS**.
   - If it **can** connect: exit code 1, **FAIL**, and the pipeline should stop.

---

## Dashboard

The CloudWatch dashboard `honeypot-fleet` (created by `terraform/logging.tf`) contains three Logs Insights widgets:

| Widget | Shows |
|--------|-------|
| Top attacker IPs | Source IPs ranked by failed login attempts |
| Top usernames tried | Most common usernames in login attempts |
| Commands run after login | Latest commands attackers executed |

---

## Cost Notes

- Fargate tasks are small (0.25 vCPU, 512 MB each).
- **Interface VPC endpoints and the Network Load Balancer are billed hourly**, even when idle.
- Run the system only for the demo window and use `terraform destroy` afterwards.
- A single availability zone is used to reduce cost.

---

## Security and Safety

- Run only in a **dedicated AWS account or isolated VPC**, never next to real workloads.
- No VPC peering and no shared IAM roles with other environments.
- The honeypot subnet has **no NAT gateway and no internet route**.
- The task security group allows inbound traffic on port 2222 only, and outbound HTTPS only to the VPC endpoints and the S3 prefix list.
- Cowrie is a medium-interaction honeypot: attackers get an emulated shell, not a real operating system.
- Do not store AWS keys or secrets in the repository.

---

## Current Status

| Component | Status |
|-----------|--------|
| Repository structure | Done |
| Terraform: network, ECS, NLB, dashboard | Written, being tested |
| Persona generator | Done |
| Weekly pipeline | Written, being tested |
| Isolation test (script and runner) | Written, not yet wired into the pipeline |
| Alarm-triggered rotation (Terraform) | TODO |
| Architecture diagram and screenshots | TODO |

---

## Limitations

- Cowrie emulates a shell, so a "compromise" in the full sense is unlikely. Rotation mainly defeats fingerprinting, and the event-based trigger relies on suspicious-activity signals rather than a confirmed breach.
- Honeypot fingerprinting can never be fully eliminated; rotation makes it harder, not impossible.
- Some configuration details (Cowrie environment variable names, log output path, NLB client-IP preservation) must be verified against a running deployment.
- Only SSH is covered so far.

---

## Future Work

- Add a fake web admin panel honeypot.
- Ship logs to S3 for long-term storage and analysis with Athena.
- Add more rotation triggers (session count spikes, uploaded malware).
- Randomise the fake filesystem contents and open ports on each rebuild.
- Multi-AZ deployment.

---

## Team

- **Eniya** - cloud infrastructure, Terraform, pipeline
  GitHub: [Eniyaanandhan6383](https://github.com/Eniyaanandhan6383)
  
---

## Disclaimer

This project is for educational and research purposes. Deploy it only in an isolated environment that you own and are authorised to use.
