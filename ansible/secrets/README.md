# Encrypted bootstrap secrets

Files in this directory are encrypted to the operator SSH public key with
`age`. They are safe to commit; the matching private key must stay outside the
repository.

Regenerate the Longhorn credential after creating or rotating the Terraform
token:

```bash
set -a
source ../../.env
set +a
python3 scripts/update_longhorn_r2_secret.py \
  --account-id YOUR_CLOUDFLARE_ACCOUNT_ID
```

The script verifies R2 API access, derives the S3 credential without writing
plaintext to disk, and replaces only the committed age ciphertext.

Apply the Longhorn R2 credentials:

```bash
ANSIBLE_STDOUT_CALLBACK=default \
uvx --from ansible-core ansible-playbook \
  playbooks/apply-longhorn-r2-secret.yml \
  -i inventory/hosts.yml
```
