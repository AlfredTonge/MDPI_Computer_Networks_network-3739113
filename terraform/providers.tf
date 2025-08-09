terraform {
  required_providers {
      hcloud = {
        source = "hetznercloud/hcloud"
      }
      cloudflare = {
        source = "cloudflare/cloudflare"
      }
  }
  backend "remote" {
    organization = "alfred-hetzner-vps"
    workspaces {
      name = "hetzner-k8s"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}