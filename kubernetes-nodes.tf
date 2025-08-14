# Kubernetes Nodes Configuration

# Get Proxmox provider configuration from 1Password
data "onepassword_item" "proxmox_provider" {
  vault = var.onepassword_homelab_vault
  title = "providers"
}



# Get all Proxmox nodes
data "proxmox_virtual_environment_nodes" "all" {
  # This will get all nodes in the cluster
}

locals {
  # Extract datastore field from Proxmox provider section with fallbacks
  proxmox_sections = [
    for section in data.onepassword_item.proxmox_provider.section : section
    if section.label == "proxmox"
  ]

  proxmox_section = length(local.proxmox_sections) > 0 ? local.proxmox_sections[0] : null

  datastore_fields = local.proxmox_section != null ? [
    for field in local.proxmox_section.field : field.value
    if field.label == "datastores"
  ] : []

  datastore_field = length(local.datastore_fields) > 0 ? local.datastore_fields[0] : "local,local-lvm"

  # Parse comma-separated datastore list and trim whitespace
  required_datastores = [
    for ds in split(",", local.datastore_field) : trimspace(ds)
  ]
  
  # Get VM ID start from Proxmox configuration
  vm_id_start_fields = local.proxmox_section != null ? [
    for field in local.proxmox_section.field : field.value
    if field.label == "vm_id_start"
  ] : []

  vm_id_start = length(local.vm_id_start_fields) > 0 ? tonumber(local.vm_id_start_fields[0]) : 200
  
  # Use the first datastore from 1Password for each type
  # This will prioritize "nas" if it's listed first in the 1Password configuration
  iso_datastore = length(local.required_datastores) > 0 ? local.required_datastores[0] : "local"
  vm_datastore = length(local.required_datastores) > 0 ? local.required_datastores[0] : "local-lvm"
  snippet_datastore = length(local.required_datastores) > 0 ? local.required_datastores[0] : "local-lvm"
  

}

# Note: Datastore validation will happen when resources are created
# If a datastore doesn't exist, the resource creation will fail with a clear error

# Download Talos image to Proxmox
resource "proxmox_virtual_environment_download_file" "talos_image" {
  content_type            = "iso"
  datastore_id            = local.iso_datastore
  node_name               = data.proxmox_virtual_environment_nodes.cluster.names[0]
  url                     = data.talos_image_factory_urls.kubernetes.urls.disk_image
  file_name               = "talos-nocloud-${var.talos_version}-${talos_image_factory_schematic.kubernetes.id}.img"
  decompression_algorithm = "zst"
  
  depends_on = []
}

# Create Kubernetes nodes 
resource "proxmox_virtual_environment_vm" "kubernetes_nodes" {
  for_each = local.kubernetes_nodes

  name        = each.key
  node_name   = try(each.value.fields.inputs.proxmox_node, data.proxmox_virtual_environment_nodes.cluster.names[0])
  description = try(each.value.fields.inputs.description, "Kubernetes node")

  vm_id = try(tonumber(each.value.fields.inputs.vm_id), local.vm_id_start + index(keys(local.kubernetes_nodes), each.key))

  cpu {
    cores = try(tonumber(each.value.fields.inputs.cpu_cores), 2)
    type  = "x86-64-v4"
  }

  memory {
    dedicated = try(tonumber(each.value.fields.inputs.memory_mb), 4096)
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = try(each.value.fields.inputs.network_bridge, "vmbr0")
    mac_address = try(each.value.fields.inputs.mac_address, null)
  }

  operating_system {
    type = "l26"
  }

  disk {
    datastore_id = try(each.value.fields.inputs.datastore, local.vm_datastore)
    file_id      = proxmox_virtual_environment_download_file.talos_image.id
    interface    = "virtio0"
    size         = try(tonumber(each.value.fields.inputs.disk_size_gb), 20)
  }

  initialization {
    datastore_id         = local.snippet_datastore
    ip_config {
      ipv4{
        address = try(each.value.fields.inputs.private_ipv4, "172.16.1.${20 + index(keys(local.kubernetes_nodes), each.key)}/24")
        gateway = try(each.value.fields.inputs.gateway, "172.16.1.1")
      }
    }
    user_data_file_id    = proxmox_virtual_environment_file.talos_user_data[each.key].id
    }

}


# Generate Talos machine secrets
resource "talos_machine_secrets" "kubernetes" {
  talos_version = var.talos_version
}

# Generate Talos machine configurations
data "talos_machine_configuration" "kubernetes_nodes" {
  for_each = local.kubernetes_nodes

  cluster_name     = "homelab-cluster"
  cluster_endpoint = "https://k8s.${var.domain_external}:6443"
  machine_type     = try(each.value.fields.inputs.node_type, "worker") == "control" ? "controlplane" : "worker"
  machine_secrets  = talos_machine_secrets.kubernetes.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              interface = "eth0"
              addresses = [try(each.value.fields.inputs.private_ipv4, "172.16.1.${20 + index(keys(local.kubernetes_nodes), each.key)}/24")]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = try(each.value.fields.inputs.gateway, "172.16.1.1")
                }
              ]
            }
          ]
          nameservers = ["172.16.1.1"]
        }
        certSANs = [
          each.key,
          "${each.key}.${var.domain_internal}",
          "${each.key}.${var.domain_external}"
        ]
        kubelet = {
          extraArgs = {
            "node-labels" = "node-type=${try(each.value.fields.inputs.node_type, "worker") == "control" ? "controlplane" : "worker"}"
          }
        }
      }
    })
  ]
}

# Generate Talos client configuration
data "talos_client_configuration" "kubernetes" {
  cluster_name = "homelab-cluster"
  endpoints    = ["172.16.1.30", "172.16.1.31"]  # Control plane endpoints
  nodes        = ["172.16.1.30", "172.16.1.31"]  # Control plane nodes
  client_configuration = talos_machine_secrets.kubernetes.client_configuration
}

# Bootstrap the Kubernetes cluster using the Talos provider
resource "talos_machine_bootstrap" "kubernetes" {
  depends_on = [
    proxmox_virtual_environment_vm.kubernetes_nodes
  ]

  client_configuration = data.talos_client_configuration.kubernetes.client_configuration
  node                 = "172.16.1.30"  # First control plane node
}

# Generate the Kubernetes kubeconfig after bootstrap
resource "talos_cluster_kubeconfig" "kubernetes" {
  depends_on = [
    talos_machine_bootstrap.kubernetes
  ]

  client_configuration = data.talos_client_configuration.kubernetes.client_configuration
  node                 = "172.16.1.30"  # First control plane node
}

# Always generate config files (triggers on every apply)
resource "null_resource" "generate_configs" {
  depends_on = [
    talos_cluster_kubeconfig.kubernetes
  ]

  triggers = {
    # This will trigger on every apply
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p config
      
      # Save Talos config using provider's talos_config attribute
      echo '${data.talos_client_configuration.kubernetes.talos_config}' > config/talosconfig
      chmod 600 config/talosconfig
      echo "✅ Talos config saved to config/talosconfig"
      
      # Save kubeconfig
      tofu output -raw kubeconfig > config/kubeconfig
      chmod 600 config/kubeconfig
      echo "✅ Kubeconfig saved to config/kubeconfig"
    EOT
  }
}

# Create Talos user-data files
resource "proxmox_virtual_environment_file" "talos_user_data" {
  for_each = local.kubernetes_nodes

  content_type = "snippets"
  datastore_id = local.snippet_datastore
  node_name    = try(each.value.fields.inputs.proxmox_node, data.proxmox_virtual_environment_nodes.cluster.names[0])

  source_raw {
    data = data.talos_machine_configuration.kubernetes_nodes[each.key].machine_configuration
    file_name = "${each.key}-user-data"
  }
}





# Tailscale device creation for Kubernetes nodes
# Note: Tailscale devices are created via API, not as Terraform resources
# You'll need to create devices manually in Tailscale or use their API

# Note: 1Password items are created by the script, not by Terraform
# Terraform only reads the items to get configuration data
# Updates to 1Password items should be done manually or via the script

# Note: Datastore selection is working automatically based on content types
# The system selects the best available datastore for each file type:
# - ISO images: datastores supporting "iso" content type
# - VM disks: datastores supporting "images" or "rootdir" content types  
# - Snippets: datastores supporting "snippets" content type
