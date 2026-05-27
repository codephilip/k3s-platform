terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token != "" ? var.cloudflare_api_token : null
}

# A record per subdomain: <subdomain>.<domain> → ingress IP.
# `name` accepts a short label (e.g. "*.apps"); the zone is implied via `zone_id`.
# `ttl = 1` is Cloudflare's magic value for "Auto" — required when proxied is true.
resource "cloudflare_dns_record" "ingress" {
  for_each = toset(var.subdomains)

  zone_id = var.zone_id
  name    = each.value
  content = var.ingress_ip
  type    = "A"
  ttl     = var.proxied ? 1 : 300
  proxied = var.proxied
}
