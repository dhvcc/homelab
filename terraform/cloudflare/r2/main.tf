resource "cloudflare_r2_bucket" "longhorn_backups" {
  account_id = var.account_id
  name       = var.longhorn_backup_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_r2_bucket" "terraform_state" {
  account_id = var.account_id
  name       = var.terraform_state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

import {
  to = cloudflare_r2_bucket.longhorn_backups
  id = "${var.account_id}/${var.longhorn_backup_bucket_name}/default"
}
