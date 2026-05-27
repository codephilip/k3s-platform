# Optional: one Hetzner server + firewall (SSH, HTTP, HTTPS, k3s API). See terraform.tfvars.example.
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token != "" ? var.hcloud_token : null
}

# Firewall: SSH, HTTP, HTTPS, k3s API. Attached to the server so ingress and TLS work out of the box.
resource "hcloud_firewall" "k3s" {
  name = "${var.server_name}-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "node" {
  name        = var.server_name
  server_type = var.server_type
  location    = var.location
  image       = var.image

  ssh_keys = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.k3s.id]

  # Optional: install k3s via user_data (cloud-init). Uncomment and add your install script.
  # user_data = file("${path.module}/k3s-install.yaml")
}

resource "hcloud_ssh_key" "default" {
  name       = "${var.server_name}-key"
  public_key = var.ssh_public_key
}
