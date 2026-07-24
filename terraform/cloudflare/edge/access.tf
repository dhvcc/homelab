resource "cloudflare_zero_trust_access_policy" "admin" {
  account_id = var.account_id
  name       = "Me"
  decision   = "allow"

  include = [
    for email in var.admin_emails : {
      email = {
        email = email
      }
    }
  ]

  session_duration = "730h"

  connection_rules = {
    rdp = {
      allowed_clipboard_local_to_remote_formats = ["text"]
      allowed_clipboard_remote_to_local_formats = ["text"]
    }
  }
}

resource "cloudflare_zero_trust_access_application" "homelab" {
  for_each = local.access_apps

  account_id                 = var.account_id
  name                       = each.key
  type                       = "self_hosted"
  domain                     = "${each.value.hostname}.${var.zone_name}"
  destinations               = [{ type = "public", uri = "${each.value.hostname}.${var.zone_name}" }]
  allowed_idps               = var.identity_provider_ids
  app_launcher_visible       = true
  auto_redirect_to_identity  = each.value.auto_redirect_to_identity
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  options_preflight_bypass   = false
  session_duration           = "24h"

  policies = [{
    id         = cloudflare_zero_trust_access_policy.admin.id
    precedence = 1
  }]
}
