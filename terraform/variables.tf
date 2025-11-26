variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for provisioning"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1"
}

variable "puppet_master_type" {
  description = "Server type for Puppet master"
  type        = string
  default     = "cx22"
}

variable "puppet_agent_type" {
  description = "Server type for Puppet agents"
  type        = string
  default     = "cx22"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}
