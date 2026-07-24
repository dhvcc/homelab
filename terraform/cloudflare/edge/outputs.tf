output "access_application_ids" {
  description = "Homelab Access application IDs keyed by name."
  value       = { for name, app in cloudflare_zero_trust_access_application.homelab : name => app.id }
}

output "tunnel_ids" {
  description = "Homelab tunnel IDs keyed by purpose."
  value       = { for name, tunnel in cloudflare_zero_trust_tunnel_cloudflared.homelab : name => tunnel.id }
}
