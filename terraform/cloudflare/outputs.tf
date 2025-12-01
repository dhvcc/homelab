output "ingress_tunnel_token" {
  value     = cloudflare_tunnel.ingress.tunnel_token
  sensitive = true
}

output "ssh_tunnel_tokens" {
  value = {
    for name, tunnel in cloudflare_tunnel.ssh : name => tunnel.tunnel_token
  }
  sensitive = true
}

