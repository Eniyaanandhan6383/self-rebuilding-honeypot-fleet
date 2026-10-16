variable "region" {
  type    = string
  default = "ap-south-1"
}

# Written by scripts/generate_persona.py into persona.auto.tfvars.json
variable "honeypot_hostname" {
  type    = string
  default = "svr04"
}

variable "ssh_version" {
  type    = string
  default = "SSH-2.0-OpenSSH_7.4"
}

variable "desired_count" {
  type    = number
  default = 2
}
