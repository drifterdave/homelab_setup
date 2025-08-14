terraform {
  required_version = ">= 1.8.0"
  required_providers {
    onepassword = {
      source  = "1password/onepassword"
      version = "2.1.2"    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.81.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0-alpha.0"    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.21.1"    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }

  }
}

# 1Password configuration
data "onepassword_item" "providers" {
  vault = var.onepassword_homelab_vault
  title = "providers"
}

locals {
  providers = {
    for section in try(data.onepassword_item.providers.section, []) : section.label => {
      for field in section.field : field.label => field.value
    }
  }
}

# Provider configurations
provider "onepassword" {}

provider "proxmox" {
  endpoint  = local.providers.proxmox.endpoint
  username  = local.providers.proxmox.username
  password  = local.providers.proxmox.password
  api_token = local.providers.proxmox.api_token
  insecure  = try(local.providers.proxmox.insecure, false)
  ssh {
    username = local.providers.proxmox.username
    password = local.providers.proxmox.password
    agent    = false
  }
}

provider "talos" {}

provider "tailscale" {
  api_key = local.providers.tailscale.api_key
  tailnet = local.providers.tailscale.tailnet
}

# Kubernetes providers - will be configured after cluster is ready
# provider "kubernetes" {
#   config_path = "./kubeconfig"
# }

# provider "helm" {
#   kubernetes {
#     config_path = "./kubeconfig"
#   }
# }

# Talos schematic generation
resource "talos_image_factory_schematic" "kubernetes" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/tailscale",
          "siderolabs/qemu-guest-agent"
        ]
      }
    }
  })
}

# Get Talos image URLs
data "talos_image_factory_urls" "kubernetes" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.kubernetes.id
  platform      = "nocloud"
}

# Proxmox data sources
data "proxmox_virtual_environment_nodes" "cluster" {}

# 1Password item discovery using hybrid approach

# Get vault information
data "onepassword_vault" "homelab" {
  name = var.onepassword_homelab_vault
}

data "onepassword_vault" "services" {
  name = var.onepassword_services_vault
}

# Use CLI to discover item lists, then provider to fetch details
data "external" "kubernetes_nodes_list" {
  program = ["sh", "-c", "op item list --format=json --vault='${var.onepassword_homelab_vault}' --tags kubernetes | jq -c '{stdout: (. | tostring)}'"]
}

data "external" "services_list" {
  program = ["sh", "-c", "op item list --format=json --vault='${var.onepassword_services_vault}' | jq -c '{stdout: (. | tostring)}'"]
}

data "external" "dns_records_list" {
  program = ["sh", "-c", "op item list --format=json --vault='${var.onepassword_homelab_vault}' --tags dns | jq -c '{stdout: (. | tostring)}'"]
}

locals {
  # Parse discovered items - use distinct to avoid duplicates
  kubernetes_nodes_discovered = {
    for item in distinct(jsondecode(data.external.kubernetes_nodes_list.result.stdout)) : item.title => item
  }
  
  services_discovered = {
    for item in distinct(jsondecode(data.external.services_list.result.stdout)) : item.title => item
  }
  
  dns_records_discovered = {
    for item in distinct(jsondecode(data.external.dns_records_list.result.stdout)) : item.title => item
  }
}

# Fetch item details using the provider
data "onepassword_item" "kubernetes_nodes" {
  for_each = local.kubernetes_nodes_discovered
  
  title = each.key
  vault = data.onepassword_vault.homelab.name
}

data "onepassword_item" "services" {
  for_each = local.services_discovered
  
  title = each.key
  vault = data.onepassword_vault.services.name
}

data "onepassword_item" "dns_records" {
  for_each = local.dns_records_discovered
  
  title = each.key
  vault = data.onepassword_vault.homelab.name
}

locals {
  # Process Kubernetes nodes
  kubernetes_nodes = {
    for key, item in data.onepassword_item.kubernetes_nodes : key => {
      id = item.id
      fields = {
        for section in item.section : section.label => {
          for field in section.field : field.label => field.value
        }
      }
    }
  }

  # Process services
  services = {
    for key, item in data.onepassword_item.services : key => {
      id = item.id
      fields = {
        for section in item.section : section.label => {
          for field in section.field : field.label => field.value
        }
      }
    }
  }

  # Process DNS records
  dns_records = {
    for key, item in data.onepassword_item.dns_records : key => {
      id = item.id
      fields = {
        for section in item.section : section.label => {
          for field in section.field : field.label => field.value
        }
      }
    }
  }
}
