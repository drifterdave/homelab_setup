# Outputs

output "talos_schematic_id" {
  description = "ID of the generated Talos schematic"
  value       = talos_image_factory_schematic.kubernetes.id
}

output "talos_image_url" {
  description = "URL of the generated Talos image"
  value       = data.talos_image_factory_urls.kubernetes.urls.disk_image
}

output "kubernetes_nodes" {
  description = "Information about deployed Kubernetes nodes"
  sensitive   = true
  value = {
    for k, v in local.kubernetes_nodes : k => {
      name          = k
      node_type     = try(v.fields.inputs.node_type, "worker")
      proxmox_node  = try(v.fields.inputs.proxmox_node, "pve")
      private_ipv4  = try(v.fields.inputs.private_ipv4, "auto-assigned")
      fqdn_external = "${k}.${var.domain_external}"
      fqdn_internal = "${k}.${var.domain_internal}"
    }
  }
}

output "services" {
  description = "Information about deployed services"
  value = {
    for k, v in local.services : k => {
      name          = k
      namespace     = try(v.fields.inputs.kubernetes_namespace, "default")
      replicas      = try(v.fields.inputs.kubernetes_replicas, "1")
      image         = try(v.fields.inputs.kubernetes_image, "unknown")
      port          = try(v.fields.inputs.kubernetes_port, "80")
      url           = try(v.fields.inputs.url, "${k}.${var.domain_external}")
      fqdn_internal = "${k}.${var.domain_internal}"
    }
  }
}

output "dns_records" {
  description = "Information about DNS records"
  value = {
    for k, v in local.dns_records : k => {
      name     = k
      content  = try(v.fields.inputs.content, "unknown")
      type     = try(v.fields.inputs.type, "A")
      ttl      = try(v.fields.inputs.ttl, "300")
      proxied  = try(v.fields.inputs.proxied, "false")
      wildcard = try(v.fields.inputs.wildcard, "false")
    }
  }
}

output "cluster_info" {
  description = "Kubernetes cluster information"
  value = {
    cluster_name           = "homelab-cluster"
    control_plane_endpoint = "k8s.${var.domain_internal}"
    pod_cidr               = "10.244.0.0/16"
    service_cidr           = "10.96.0.0/12"
    dns_domain             = "cluster.local"
    talos_version          = var.talos_version
  }
}

output "kubeconfig" {
  description = "Kubernetes cluster kubeconfig"
  value       = talos_cluster_kubeconfig.kubernetes.kubeconfig_raw
  sensitive   = true
}

output "talos_client_config" {
  description = "Talos client configuration"
  value       = data.talos_client_configuration.kubernetes.client_configuration
  sensitive   = true
}
