resource "cloudflare_dns_record" "tunnel" {
  for_each = local.dns_routes

  zone_id = var.zone_id
  name    = "${each.key}.${var.zone_name}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab[each.value].id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
