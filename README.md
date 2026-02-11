# Homelab

HA k3s cluster on NixOS, managed with Ansible and Helm.

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
- [ ] Better helm install and manage flow
- [x] Home Assistant + IoT network bridge


## Stack

- **NixOS** - declarative OS configuration
- **k3s** - lightweight Kubernetes
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
Edit `group_vars/all.yml` with `root_domain`, `k3s_token`, and `cloudflare_ingress_tunnel_token`.

### 2. Install NixOS

Per node:
1. Boot NixOS minimal ISO
2. Set password: `passwd nixos`
3. Run: `ansible-playbook playbooks/nixos-init.yml -i inventory/hosts.yml --limit <node>`
4. Remove USB and reboot
5. Change password from default "changeme" set by the config

First node in `k8s_control_plane` is the cluster seed.

### 3. Deploy Stack

```bash
cd ansible

# Storage (first)
ansible-playbook playbooks/deploy-helm.yml -i inventory/hosts.yml -e helm_release=longhorn

# Logging
ansible-playbook playbooks/deploy-helm.yml -i inventory/hosts.yml -e helm_release=loki
ansible-playbook playbooks/deploy-helm.yml -i inventory/hosts.yml -e helm_release=promtail

# Monitoring
ansible-playbook playbooks/deploy-helm.yml -i inventory/hosts.yml -e helm_release=kube-prometheus-stack

# Cloudflare Tunnel
ansible-playbook playbooks/deploy-cloudflare-ingress-tunnel.yml -i inventory/hosts.yml
```

### Optional: Longhorn R2 Backups

For **NEW** Longhorn deployments (recommended - declarative):
```bash
# 1. Configure r2_* variables in ansible/inventory/group_vars/all.yml
# 2. Create secret first
ansible-playbook playbooks/create-longhorn-r2-secret.yml -i inventory/hosts.yml
# 3. Edit k8s/helm/longhorn/values.yaml to uncomment and configure defaultBackupStore
# 4. Deploy Longhorn
ansible-playbook playbooks/deploy-helm.yml -i inventory/hosts.yml -e helm_release=longhorn
```

For **EXISTING** Longhorn deployments (runtime configuration):
```bash
# 1. Configure r2_* variables in ansible/inventory/group_vars/all.yml
# 2. Run runtime configuration (includes secret creation and proper waits)
ansible-playbook playbooks/configure-longhorn-r2-backup.yml -i inventory/hosts.yml
```

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
