# DNS Configuration

# Create DNS records based on 1Password entries
resource "onepassword_item" "dns_records" {
  for_each = local.dns_records

  vault = var.onepassword_homelab_vault
  title = each.key
  tags  = ["dns"]

  section {
    label = "inputs"

    field {
      label = "content"
      value = each.value.fields.content
      type  = "STRING"
    }

    field {
      label = "type"
      value = each.value.fields.type
      type  = "STRING"
    }

    field {
      label = "priority"
      value = try(each.value.fields.priority, "")
      type  = "STRING"
    }

    field {
      label = "ttl"
      value = try(each.value.fields.ttl, "300")
      type  = "STRING"
    }

    field {
      label = "proxied"
      value = try(each.value.fields.proxied, "false")
      type  = "STRING"
    }

    field {
      label = "wildcard"
      value = try(each.value.fields.wildcard, "false")
      type  = "STRING"
    }

    field {
      label = "comment"
      value = try(each.value.fields.comment, "")
      type  = "STRING"
    }
  }
}

# CoreDNS configuration for Kubernetes service discovery
# NOTE: These resources will be deployed in a separate phase after the cluster is ready
# resource "kubernetes_config_map" "coredns" {
#   metadata {
#     name      = "coredns"
#     namespace = "kube-system"
#   }

#   data = {
#     "Corefile" = templatefile("${path.module}/templates/coredns/Corefile", {
#       domain_internal = var.domain_internal
#       domain_external = var.domain_external
#       dns_domain      = "cluster.local"
#     })
#   }
# }

# # CoreDNS deployment
# resource "kubernetes_deployment" "coredns" {
#   metadata {
#     name      = "coredns"
#     namespace = "kube-system"
#   }

#   spec {
#     replicas = 2

#     selector {
#       match_labels = {
#         k8s-app = "kube-dns"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           k8s-app = "kube-dns"
#         }
#       }

#       spec {
#         container {
#           name  = "coredns"
#           image = "coredns/coredns:1.11.1"

#           args = ["-conf", "/etc/coredns/Corefile"]

#           port {
#             container_port = 53
#             name           = "dns"
#             protocol       = "UDP"
#           }

#           port {
#             container_port = 53
#             name           = "dns-tcp"
#             protocol       = "TCP"
#           }

#           volume_mount {
#             name       = "config-volume"
#             mount_path = "/etc/coredns"
#             read_only  = true
#           }
#         }

#         volume {
#           name = "config-volume"
#           config_map {
#             name = kubernetes_config_map.coredns.metadata[0].name
#           }
#         }
#       }
#     }
#   }
# }

# # CoreDNS service
# resource "kubernetes_service" "coredns" {
#   metadata {
#     name      = "kube-dns"
#     namespace = "kube-system"
#     labels = {
#       k8s-app = "kube-dns"
#     }
#   }

#   spec {
#     selector = {
#       k8s-app = "kube-dns"
#     }

#     port {
#       name        = "dns"
#       port        = 53
#       protocol    = "UDP"
#       target_port = 53
#     }

#     port {
#       name        = "dns-tcp"
#       port        = 53
#       protocol    = "TCP"
#       target_port = 53
#     }

#     cluster_ip = "10.96.0.10"
#   }

#   depends_on = [kubernetes_deployment.coredns]
# }
