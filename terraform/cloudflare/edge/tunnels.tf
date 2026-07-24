resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  for_each = local.tunnels

  account_id = var.account_id
  name       = each.value
  config_src = "cloudflare"

  lifecycle {
    prevent_destroy = true
  }
}

# The shared ingress tunnel still contains commercial and personal routes.
# Its configuration stays unmanaged until those routes move to separate tunnels.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "ssh" {
  for_each = local.ssh_ingress

  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab[each.key].id

  config = {
    ingress = each.value
  }
}
