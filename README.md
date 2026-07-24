# Homelab

HA k3s cluster on NixOS, bootstrapped with Ansible and reconciled with ArgoCD.

## Notes

- Currently all nodes are master+worker
- Longhorn config relies on having at least 2 replicas (>=2 nodes)
- Logs Drilldown plugin is downloaded straight from GH Releases, skipping any of the grafana cloud stuff
- Nixos-init uses the whole disk, formatting and installing on it

## TODO
- [ ] Fix loki-canary drop rules
- [x] Terraform for Cloudflare R2 and the homelab edge
- [ ] Move commercial routes to a separate Cloudflare Tunnel
- [ ] Better support for custom dashboards
- [ ] Better way of declaring plugin GH links for Grafana
- [x] Home Assistant + IoT network bridge


## Stack

- **NixOS** - declarative OS configuration
- **k3s** - lightweight Kubernetes
- **ArgoCD** - GitOps reconciliation for cluster apps
- **Cloudflare Tunnels** - zero-trust SSH and ingress access
- **Longhorn** - distributed block storage
- **kube-prometheus-stack** - Prometheus, Grafana, Alertmanager, node-exporter
- **Loki + Promtail** - log aggregation

## Setup

### 1. Configure Inventory

```bash
cd ansible/inventory
cp hosts.yml.example hosts.yml
cp group_vars/all.yml.example group_vars/all.yml
```

Edit `hosts.yml` with node IPs and Cloudflare SSH tunnel tokens.  
Edit `group_vars/all.yml` with `k3s_token`, `cloudflare_ingress_tunnel_token`, and any optional ArgoCD repo overrides.

For each control-plane node in `hosts.yml`:
- `ansible_host` is only for operator access and SSH. It can be a Cloudflare/public hostname.
- `k3s_address` is the node's control-plane/peer address used by k3s. Use a LAN IP or internal DNS name, not a public Cloudflare hostname.
- `k3s_join_address` is optional. When set, non-seed nodes join that LAN/internal k3s endpoint instead of the seed node's `k3s_address`.

### 2. Install NixOS

Per node:
1. Boot NixOS minimal ISO
2. Set password: `passwd nixos`
3. Run: `ansible-playbook playbooks/nixos-init.yml -i inventory/hosts.yml --limit <node>`
4. Remove USB and reboot
5. Change password from default "changeme" set by the config

First node in `k8s_control_plane` is the cluster seed.
By default, other control-plane nodes join that seed via its `k3s_address`.

### 3. Bootstrap ArgoCD

```bash
cd ansible

ansible-playbook playbooks/install-argocd.yml -i inventory/hosts.yml
```

This installs ArgoCD, applies the upstream `AppProject` and root `Application`, and bootstraps the rest of the stack from Git. After this point, update Kubernetes apps by changing manifests or values in Git and letting ArgoCD sync them.

If you want ArgoCD to track a private repo instead of upstream defaults, set `argocd_repo_url`, `argocd_target_revision`, and optional repo credentials in `group_vars/all.yml` before running the playbook.

### 4. Operate Apps with GitOps

- Edit values under `k8s/helm/<app>/values.yaml` or manifests under `k8s/`.
- Commit and push those changes to the repo ArgoCD is tracking.
- Let ArgoCD reconcile the cluster; no Ansible run is needed for app updates.

Upstream ships fully usable ArgoCD applications pointing at this repo by default. A private repo can layer on top by patching `repoURL` and `targetRevision` to follow itself instead.

### Optional: Longhorn R2 Backups

Longhorn backs up all volumes in the `default` recurring-job group to
Cloudflare R2 every day at 02:15 UTC and retains seven backups per volume.

Bootstrap the encrypted credential before ArgoCD applies the backup target:

```bash
cd ansible
ANSIBLE_STDOUT_CALLBACK=default \
uvx --from ansible-core ansible-playbook \
  playbooks/apply-longhorn-r2-secret.yml \
  -i inventory/hosts.yml
```

The encrypted secret is committed under `ansible/secrets/`; the age identity
stays outside Git. Terraform under `terraform/cloudflare/r2/` manages the R2
buckets.

### Cloudflare Terraform Credentials

This personal homelab uses one scoped Terraform token for Cloudflare edge and
R2. Create it under **Manage account > Account API tokens > Create a token >
Custom**:

1. Name it `homelab-terraform-edge`.
2. Add an **Entire Account** policy with:
   - `Access: Apps and Policies` — Write
   - `Access: Groups` — Write
   - `Cloudflare One Connector: cloudflared` — Write
   - `Workers R2 Storage` — Write
3. Add a **Specified Domains** policy for the homelab domain with:
   - `DNS` — Write
   - `Zone` — Read
4. Leave IP filtering empty. A dynamic home IP would eventually lock
   Terraform out.
5. Use no expiration unless token rotation is automated.

Save the value immediately after creation; Cloudflare only shows it once. Put
it in the ignored root `.env`, never in Terraform variables, inventory, Git,
shell history, or documentation:

```bash
CLOUDFLARE_API_TOKEN="..."
```

The token has no billing, account administration, identity provider, service
token, or unrelated zone access. Splitting it further adds operational
overhead without a useful security boundary for this single-user homelab.

### Optional: Home Network Bridge (IoT Access)

Bridges homelab to home network (192.168.0.0/24) via OpenWRT's 5GHz WiFi radio. Enables Home Assistant to reach IoT devices on the home network.

```bash
# 1. Add openwrt host to hosts.yml (see hosts.yml.example)
# 2. Configure home_wifi_ssid and home_wifi_password in group_vars/all.yml
# 3. Run bridge playbook
ansible-playbook playbooks/openwrt-home-lan.yml -i inventory/hosts.yml
```

Traffic is NAT'd — no changes needed on the home network. To revert:
```bash
# SSH to OpenWRT, then:
uci revert wireless; uci revert network; uci revert firewall; /etc/init.d/network restart
```

## Operations

Update node config:
```bash
ansible-playbook playbooks/nixos-update.yml -i inventory/hosts.yml
```

ArgoCD-managed apps update from Git. Ansible is only for node lifecycle, bootstrap, and non-GitOps machine configuration.

For control-plane recovery, make sure `k3s_address` and any `k3s_join_address` values stay on the LAN or internal DNS. Do not point k3s peer/bootstrap traffic at public Cloudflare hostnames from `ansible_host`.

Reset k3s on a node (rejoin cluster):
```bash
ansible-playbook playbooks/nixos-update.yml -i inventory/hosts.yml -e reset_k3s=true --limit <node>
```

## SSH via Cloudflare (Short-Lived Certs)

Set these per control-plane node in `ansible/inventory/hosts.yml`:
- `cloudflare_ssh_ca_pubkey`
- `cloudflare_ssh_allowed_principals` (must include your Cloudflare cert principal)

Generate per-node local SSH config blocks (localhost only):
```bash
cd ansible
ansible-playbook playbooks/configure-local-cloudflare-ssh.yml -i inventory/hosts.yml
```

This writes explicit entries for each `k8s_control_plane` host in `~/.ssh/config` and keeps cert generation per host/app.

Then connect directly using inventory hostnames:
```bash
ssh nixos@<control-plane-ansible_host>
```

To see your principal from a generated cert:
```bash
ssh-keygen -Lf ~/.cloudflared/<host>-cf_key-cert.pub
```

Password auth remains enabled by default for rollback (`ssh_password_auth_enabled: true`) and can be disabled later by setting it to `false` and applying `nixos-update.yml`.
