locals {
  provider_proxmox_raw = yamldecode(file("${var.credentials_dir}/terraform_proxmox.yaml"))
  provider_proxmox_api_token = local.provider_proxmox_raw.proxmox_api_token
  provider_proxmox_api_endpoint = local.provider_proxmox_raw.proxmox_api_endpoint
}

terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.118.1"
    }
  }
}

provider "proxmox" {
  endpoint = local.provider_proxmox_api_endpoint
  api_token = local.provider_proxmox_api_token
#  insecure = true
}
