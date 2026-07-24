variable "account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "zone_id" {
  description = "Cloudflare zone ID."
  type        = string
}

variable "zone_name" {
  description = "Cloudflare zone used for homelab hostnames."
  type        = string
  default     = "dhvcc.me"
}

variable "admin_emails" {
  description = "Emails allowed by the shared homelab administrator policy."
  type        = list(string)
}

variable "identity_provider_ids" {
  description = "Identity providers allowed by homelab Access applications."
  type        = list(string)
}
