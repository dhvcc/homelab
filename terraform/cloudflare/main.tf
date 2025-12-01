terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "main" {
  name = var.domain
}

# Ingress tunnel (for k8s services)
resource "cloudflare_tunnel" "ingress" {
  account_id = var.cloudflare_account_id
  name       = "homelab-ingress"
  secret     = base64encode(var.ingress_tunnel_secret)
}

resource "cloudflare_tunnel_config" "ingress" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.ingress.id

  config {
    ingress_rule {
      hostname = "grafana.${var.domain}"
      service  = "http://ingress-nginx-controller.homelab.svc.cluster.local:80"
    }
    ingress_rule {
      hostname = "longhorn.${var.domain}"
      service  = "http://ingress-nginx-controller.homelab.svc.cluster.local:80"
    }
    # Catch-all rule (required)
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# DNS records pointing to tunnel
resource "cloudflare_record" "grafana" {
  zone_id = data.cloudflare_zone.main.id
  name    = "grafana"
  content = "${cloudflare_tunnel.ingress.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "longhorn" {
  zone_id = data.cloudflare_zone.main.id
  name    = "longhorn"
  content = "${cloudflare_tunnel.ingress.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# SSH tunnels (one per node)
resource "cloudflare_tunnel" "ssh" {
  for_each   = var.ssh_nodes
  account_id = var.cloudflare_account_id
  name       = "homelab-ssh-${each.key}"
  secret     = base64encode(each.value.tunnel_secret)
}

resource "cloudflare_tunnel_config" "ssh" {
  for_each   = var.ssh_nodes
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.ssh[each.key].id

  config {
    ingress_rule {
      hostname = "${each.key}.${var.domain}"
      service  = "ssh://localhost:22"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "ssh" {
  for_each = var.ssh_nodes
  zone_id  = data.cloudflare_zone.main.id
  name     = each.key
  content  = "${cloudflare_tunnel.ssh[each.key].id}.cfargotunnel.com"
  type     = "CNAME"
  proxied  = true
}

# Zero Trust access application for SSH
resource "cloudflare_access_application" "ssh" {
  zone_id          = data.cloudflare_zone.main.id
  name             = "Homelab SSH"
  domain           = "*.${var.domain}"
  type             = "ssh"
  session_duration = "24h"
}

resource "cloudflare_access_policy" "ssh" {
  zone_id        = data.cloudflare_zone.main.id
  application_id = cloudflare_access_application.ssh.id
  name           = "Allow authenticated users"
  precedence     = 1
  decision       = "allow"

  include {
    email = var.allowed_emails
  }
}

