output "server_ip" {
  value       = hcloud_server.node.ipv4_address
  description = "Public IP of the server (use as ingress_ip for DNS / Traefik)"
}

output "server_name" {
  value       = hcloud_server.node.name
  description = "Server name in Hetzner"
}
