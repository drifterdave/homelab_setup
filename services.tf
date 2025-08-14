# Kubernetes Services Configuration
# NOTE: These resources will be deployed in a separate phase after the cluster is ready
# Uncomment this file after the Kubernetes cluster is fully operational

# Create Kubernetes namespaces for services
resource "kubernetes_namespace" "services" {
  for_each = local.services

  metadata {
    name = try(each.value.fields.kubernetes_namespace, "default")
  }
}

# Create Kubernetes deployments
resource "kubernetes_deployment" "services" {
  for_each = local.services

  metadata {
    name      = each.key
    namespace = try(each.value.fields.kubernetes_namespace, "default")
  }

  spec {
    replicas = try(tonumber(each.value.fields.kubernetes_replicas), 1)

    selector {
      match_labels = {
        app = each.key
      }
    }

    template {
      metadata {
        labels = {
          app = each.key
        }
      }

      spec {
        container {
          image = each.value.fields.kubernetes_image
          name  = each.key

          port {
            container_port = try(tonumber(each.value.fields.kubernetes_port), 80)
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.services]
}

# Create Kubernetes services
resource "kubernetes_service" "services" {
  for_each = local.services

  metadata {
    name      = each.key
    namespace = try(each.value.fields.kubernetes_namespace, "default")
  }

  spec {
    selector = {
      app = each.key
    }

    port {
      port        = try(tonumber(each.value.fields.kubernetes_port), 80)
      target_port = try(tonumber(each.value.fields.kubernetes_port), 80)
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.services]
}

# Create Kubernetes ingress resources
resource "kubernetes_ingress_v1" "services" {
  for_each = local.services

  metadata {
    name      = each.key
    namespace = try(each.value.fields.kubernetes_namespace, "default")
    annotations = {
      "kubernetes.io/ingress.class"    = "nginx"
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }

  spec {
    rule {
      host = try(each.value.fields.url, "${each.key}.${var.domain_external}")
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = each.key
              port {
                number = try(tonumber(each.value.fields.kubernetes_port), 80)
              }
            }
          }
        }
      }
    }

    tls {
      hosts       = [try(each.value.fields.url, "${each.key}.${var.domain_external}")]
      secret_name = "${each.key}-tls"
    }
  }

  depends_on = [kubernetes_service.services]
}

# 1Password item updates for services
resource "onepassword_item" "services" {
  for_each = local.services

  vault = var.onepassword_services_vault
  title = each.key

  section {
    label = "outputs"

    field {
      label = "fqdn_external"
      value = try(each.value.fields.url, "${each.key}.${var.domain_external}")
      type  = "URL"
    }

    field {
      label = "fqdn_internal"
      value = "${each.key}.${var.domain_internal}"
      type  = "URL"
    }

    field {
      label = "kubernetes_namespace"
      value = try(each.value.fields.kubernetes_namespace, "default")
      type  = "STRING"
    }
  }
}
