terraform {
  required_providers {
    openwrt = {
      source  = "joneshf/openwrt"
      version = "~> 0.0"
    }
  }
}

provider "openwrt" {
  hostname = var.openwrt_host
  username = var.openwrt_username
  password = var.openwrt_password
}

# Interface for IoT network connection
resource "openwrt_network_interface" "iot" {
  name     = "iot"
  proto    = "static"
  device   = var.iot_interface_device # e.g., "eth1" or "lan2"
  ipaddr   = var.iot_ip
  netmask  = var.iot_netmask
  gateway  = var.iot_gateway
  dns      = [var.iot_gateway]
}

# Firewall zone for IoT network
resource "openwrt_firewall_zone" "iot" {
  name    = "iot"
  input   = "REJECT"
  output  = "ACCEPT"
  forward = "REJECT"
  network = [openwrt_network_interface.iot.name]
}

# Allow homelab (LAN) to reach IoT
resource "openwrt_firewall_forwarding" "lan_to_iot" {
  src  = "lan"
  dest = "iot"
}

# Block IoT from reaching homelab (except established connections)
# IoT devices don't need to initiate connections to k8s cluster

