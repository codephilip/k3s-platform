output "ingress_fqdns" {
  value       = [for s in var.subdomains : "${s}.${var.domain}"]
  description = "FQDNs that now point at your ingress IP"
}

output "ingress_ip" {
  value       = var.ingress_ip
  description = "IP the DNS record points to"
}
