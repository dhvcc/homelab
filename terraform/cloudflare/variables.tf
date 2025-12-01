variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_account_id" {
  type = string
}

variable "domain" {
  type = string
}

variable "ingress_tunnel_secret" {
  type      = string
  sensitive = true
}

variable "ssh_nodes" {
  type = map(object({
    tunnel_secret = string
  }))
  description = "Map of node names to their SSH tunnel secrets"
}

variable "allowed_emails" {
  type        = list(string)
  description = "Emails allowed to access SSH via Cloudflare Access"
}

