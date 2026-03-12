# Homelab

HA k3s cluster on NixOS, bootstrapped with Ansible and reconciled with ArgoCD.

## Notes

- Currently all nodes are master+worker
- Longhorn config relies on having at least 2 replicas (>=2 nodes)
- Logs Drilldown plugin is downloaded straight from GH Releases, skipping any of the grafana cloud stuff
- Nixos-init uses the whole disk, formatting and installing on it

## TODO
- [ ] Fix loki-canary drop rules
- [ ] TF For CF
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

### 2. Install NixOS

Per node:
1. Boot NixOS minimal ISO
2. Set password: `passwd nixos`
3. Run: `ansible-playbook playbooks/nixos-init.yml -i inventory/hosts.yml --limit <node>`
4. Remove USB and reboot
5. Change password from default "changeme" set by the config

First node in `k8s_control_plane` is the cluster seed.

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

For declarative Longhorn backups:
```bash
# 1. Configure r2_* variables in ansible/inventory/group_vars/all.yml
# 2. Create the backup secret in your tracked repo or bootstrap it separately
# 3. Edit k8s/helm/longhorn/values.yaml to configure defaultBackupStore
# 4. Commit and push; ArgoCD will apply the Longhorn change
```

Keep backup secrets out of Git unless your private repo already has a sealed/external secret flow.

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
