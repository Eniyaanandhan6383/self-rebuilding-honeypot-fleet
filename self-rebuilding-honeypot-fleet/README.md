# Self-Rebuilding Honeypot Fleet

A fleet of containerized honeypots (Cowrie SSH) running in a locked-down AWS VPC with **no outbound internet**.
Honeypots are destroyed and rebuilt automatically with a new identity (hostname, SSH banner), so attackers cannot fingerprint them, and a compromised one cannot be used as a launch pad.

> Status: work in progress. Structure and starter code are in place; details are being finalised.

## Problem
Honeypots that stay unchanged for weeks get fingerprinted and ignored. A compromised honeypot can also become a launch pad for real attacks.
See [docs/problem-statement.md](docs/problem-statement.md).

## Solution
1. Cowrie honeypot runs in a Docker container on AWS Fargate (private subnet, no NAT, no internet gateway route).
2. Attackers reach it through a Network Load Balancer (port 22 -> container port 2222).
3. Attacker activity is logged to CloudWatch Logs and shown on a dashboard.
4. Weekly pipeline generates a new persona, runs security checks, redeploys with Terraform, and tests that outbound traffic is still blocked.
5. An alarm-triggered Lambda can force a rebuild when suspicious activity is seen.

## Tech stack
Docker, Terraform, AWS (VPC, VPC endpoints, ECS Fargate, ECR, NLB, CloudWatch, Lambda), GitHub Actions, Python, Checkov.

## Repo structure
| Path | What it contains |
|------|------------------|
| `honeypot/` | Dockerfile and Cowrie config |
| `terraform/` | All AWS infrastructure (network, ECS, NLB, logging) |
| `scripts/generate_persona.py` | Picks a new random hostname/SSH banner for each rebuild |
| `lambda/rotate_on_alert.py` | Forces a redeploy when an alarm fires |
| `tests/isolation_test/` | Test that proves the honeypot cannot reach the internet |
| `.github/workflows/rebuild.yml` | Weekly rebuild pipeline |
| `docs/` | Problem statement, architecture diagram, screenshots |

## How to deploy (draft)
1. Install Docker, Terraform, AWS CLI. Configure AWS credentials for a **separate/isolated AWS account**.
2. `cd terraform && terraform init`
3. `terraform apply -target=aws_ecr_repository.honeypot`
4. Build and push the image from `honeypot/` to the ECR repo.
5. `python scripts/generate_persona.py` (from repo root)
6. `terraform apply`
7. Connect to the NLB DNS name (`terraform output nlb_dns_name`) on port 22 to test.
8. Remove everything after the demo: `terraform destroy`.

## Safety notes
- Run only in a dedicated AWS account or isolated VPC, never next to real workloads.
- The task security group has no general egress; the pipeline is meant to fail if isolation breaks.
- Interface endpoints and the NLB are billed hourly. Destroy after demos and set a budget alarm.

## Team
- Eniya (cloud infrastructure)

## Future work
- Add a fake web admin panel honeypot
- Ship logs to S3 for long-term analysis
- More rotation triggers
