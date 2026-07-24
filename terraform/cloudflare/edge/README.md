# Cloudflare edge

This stack owns the public homelab edge:

- the shared administrator Access policy;
- Access applications for homelab services and SSH;
- the four homelab Cloudflare Tunnels;
- SSH tunnel ingress configuration;
- DNS records that point homelab hostnames at those tunnels.

It intentionally does not own commercial Access applications, commercial DNS,
the App Launcher, identity providers, service tokens, or the mixed
`homelab-k8s` ingress configuration. Commercial routes must move to a separate
tunnel before that configuration can be managed without coupling the public
and private repositories.

## Credentials

Create the token exactly as documented in the repository root README and save
it as `CLOUDFLARE_API_TOKEN` in the ignored root `.env`. It is read directly
by the provider and is not stored in tfvars.

```bash
cd terraform/cloudflare/edge
set -a
source ../../../.env
set +a

terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
```

Copy `terraform.tfvars.example` to the ignored `terraform.tfvars` and
`backend.hcl.example` to the ignored `backend.hcl`. Store the S3 backend
credentials only in `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`; the
derivation commands are documented in `../r2/README.md`.

Existing resources must be imported before the first plan. Do not apply a plan
that proposes recreating a tunnel, replacing DNS, or deleting unmanaged
commercial resources.
