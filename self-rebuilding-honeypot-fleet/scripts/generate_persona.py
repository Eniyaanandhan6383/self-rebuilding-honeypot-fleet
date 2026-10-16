# Picks a new random honeypot identity and writes it where Terraform reads it.
# Run from repo root: python scripts/generate_persona.py
import json
import random

hostnames = ["db-prod-02", "web-backup", "fileserver01", "jenkins-old", "nas-gateway"]
ssh_versions = [
    "SSH-2.0-OpenSSH_7.4",
    "SSH-2.0-OpenSSH_8.2p1 Ubuntu-4ubuntu0.5",
    "SSH-2.0-OpenSSH_7.9p1 Debian-10+deb10u2",
    "SSH-2.0-OpenSSH_8.9p1",
]

persona = {
    "honeypot_hostname": random.choice(hostnames) + "-" + str(random.randint(10, 99)),
    "ssh_version": random.choice(ssh_versions),
}

with open("terraform/persona.auto.tfvars.json", "w") as f:
    json.dump(persona, f, indent=2)

print("new persona:", persona)
