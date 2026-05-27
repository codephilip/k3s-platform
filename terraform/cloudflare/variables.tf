variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token (or set CLOUDFLARE_API_TOKEN env var)"
  sensitive   = true
  default     = ""
}

variable "zone_id" {
  type        = string
  description = "Cloudflare zone ID for your domain (e.g. from dashboard or API)"
}

variable "domain" {
  type        = string
  description = "Root domain managed in Cloudflare (e.g. example.com)"
}

variable "ingress_ip" {
  type        = string
  description = "Public IP of your k3s ingress (Traefik LoadBalancer or node)"
}

variable "subdomains" {
  type        = list(string)
  description = "Subdomain labels (e.g. \"*.apps\", \"*.api\" for dev.apps.<domain>, dev.api.<domain>). Creates <sub>.<domain> → ingress_ip for each"
  default     = ["*.apps", "*.api"]
}

variable "proxied" {
  type        = bool
  description = "Whether to proxy through Cloudflare (orange cloud)"
  default     = false
}
