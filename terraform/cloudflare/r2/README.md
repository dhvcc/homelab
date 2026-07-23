# Cloudflare R2

This stack adopts the existing Longhorn backup bucket and creates a separate
bucket for Terraform state.

Authentication is read from `CLOUDFLARE_API_TOKEN`. The token needs only
`Workers R2 Storage Write` for the target Cloudflare account.

Copy `backend.hcl.example` to the ignored `backend.hcl` and replace
`ACCOUNT_ID`. The S3 backend uses credentials derived from the same R2 API
token:

```bash
export AWS_ACCESS_KEY_ID="$(curl -fsS \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$TF_VAR_account_id/tokens/verify" \
  | jq -r .result.id)"
export AWS_SECRET_ACCESS_KEY="$(printf %s "$CLOUDFLARE_API_TOKEN" \
  | shasum -a 256 | awk '{print $1}')"

terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

Both buckets use `prevent_destroy`. Do not remove that guard during normal
operation.
