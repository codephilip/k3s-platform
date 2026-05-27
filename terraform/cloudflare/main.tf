terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token != "" ? var.cloudflare_api_token : null
}

data "cloudflare_zone" "main" {
  zone_id = var.zone_id
}

# A record per subdomain: <subdomain>.<domain> → ingress IP (e.g. *.apps.example.com, *.api.example.com for dev.apps, staging.api, etc.)
resource "cloudflare_record" "ingress" {
  for_each = toset(var.subdomains)

  zone_id = var.zone_id
  name    = each.value
  content = var.ingress_ip
  type    = "A"
  ttl     = var.proxied ? 1 : 300
  proxied = var.proxied
}
