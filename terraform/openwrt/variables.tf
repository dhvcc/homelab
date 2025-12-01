variable "openwrt_host" {
  type        = string
  description = "OpenWRT router hostname/IP"
}

variable "openwrt_username" {
  type    = string
  default = "root"
}

variable "openwrt_password" {
  type      = string
  sensitive = true
}

variable "iot_interface_device" {
  type        = string
  description = "Physical interface connected to IoT network (e.g., eth1, lan2)"
}

variable "iot_ip" {
  type        = string
  description = "IP address for OpenWRT on IoT network"
}

variable "iot_netmask" {
  type    = string
  default = "255.255.255.0"
}

variable "iot_gateway" {
  type        = string
  description = "IoT network gateway (TP-Link router IP)"
}

