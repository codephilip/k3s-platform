variable "hcloud_token" {
  type        = string
  description = "Hetzner Cloud API token (or set HCLOUD_TOKEN env var)"
  sensitive   = true
  default     = ""
}

variable "server_name" {
  type        = string
  description = "Name of the server in Hetzner"
  default     = "k3s-node"
}

variable "server_type" {
  type        = string
  description = "Hetzner server type (e.g. cx22, cpx21)"
  default     = "cx22"
}

variable "location" {
  type        = string
  description = "Hetzner location (fsn1, nbg1, hel1)"
  default     = "fsn1"
}

variable "image" {
  type        = string
  description = "Server image (ubuntu-22.04, etc.)"
  default     = "ubuntu-22.04"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for server access"
}
