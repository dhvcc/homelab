output "longhorn_backup_bucket_name" {
  value = cloudflare_r2_bucket.longhorn_backups.name
}

output "terraform_state_bucket_name" {
  value = cloudflare_r2_bucket.terraform_state.name
}
