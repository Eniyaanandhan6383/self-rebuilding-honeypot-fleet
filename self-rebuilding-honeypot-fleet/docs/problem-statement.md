# Problem Statement

Honeypots (fake systems that attract attackers) get fingerprinted and ignored once they stay the same for weeks.
A compromised honeypot is also dangerous, because it can become a launch pad for real attacks.

# Proposed Solution

A fleet of containerized honeypots (Cowrie for SSH) runs in a locked-down VPC with no outbound internet access.
Attacker activity is logged to CloudWatch. On a schedule, or on suspicious activity, honeypots are destroyed and replaced by fresh ones with a different banner and hostname. A dashboard shows who attacked what and how.

# Why each tool is needed
- Docker: honeypots must be disposable and reset to a clean state instantly.
- Terraform: network isolation and each rotation are infrastructure operations; safe teardown and recreation is the core feature.
- Pipeline: rebuilds weekly with a new identity and verifies isolation still blocks outbound traffic before exposing anything.
