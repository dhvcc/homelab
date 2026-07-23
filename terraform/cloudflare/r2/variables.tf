variable "account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "longhorn_backup_bucket_name" {
  description = "R2 bucket used by Longhorn."
  type        = string
  default     = "longhorn-backups"
}

variable "terraform_state_bucket_name" {
  description = "R2 bucket reserved for Terraform state."
  type        = string
  default     = "homelab-terraform-state"
}
