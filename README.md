# Homelab

HA k3s cluster on NixOS, managed with Ansible and Helmfile.

## Notes

- Currently all nodes are master+worker
- Longhorn config relies on having at least 2 replicas (>=2 nodes)
- Logs Drilldown plugin is downloaded straight from GH Releases, skipping any of the grafana cloud stuff
- Nixos-init uses the whole disk, formatting and installing on it

## TODO
- [ ] Fix loki-canary drop rules
- [x] TF For CF
- [x] Better support for custom dashboards
- [ ] Better way of declaring plugin GH links for Grafana
- [ ] Better helm install and manage flow
- [ ] Home Assistant + IoT network bridge


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

## Operations

Update node config:
```bash
ansible-playbook playbooks/nixos-update.yml -i inventory/hosts.yml
```

Reset k3s on a node (rejoin cluster):
```bash
ansible-playbook playbooks/nixos-update.yml -i inventory/hosts.yml -e reset_k3s=true --limit <node>
```

## SSH via Cloudflare

Add to `~/.ssh/config`:
```
Host node1.domain.com
  ProxyCommand cloudflared access ssh --hostname %h
```

## Terraform

Infrastructure-as-code for external services.

```bash
cd terraform/cloudflare
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init && terraform apply
```

### Modules

- `cloudflare/` - Tunnels, DNS records, Zero Trust access policies
- `openwrt/` - Network interface and firewall for IoT bridge (WIP)

#### Note
OpenWRT: The terraform provider (joneshf/openwrt) is community-maintained and uses LuCI RPC. It's a bit experimental - you may need to enable luci-mod-rpc on the router. If it doesn't work well, manual UCI config is fine:

```
uci set network.iot=interface
uci set network.iot.proto='static'
uci set network.iot.device='eth1'
uci set network.iot.ipaddr='192.168.1.250'
uci set network.iot.netmask='255.255.255.0'
uci commit network
/etc/init.d/network restart
```
