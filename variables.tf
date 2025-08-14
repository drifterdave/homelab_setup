variable "onepassword_homelab_vault" {
  description = "1Password homelab vault name"
  type        = string
  default     = "Homelab"
}

variable "onepassword_services_vault" {
  description = "1Password services vault name"
  type        = string
  default     = "Services"
}

variable "talos_version" {
  description = "Talos Linux version to use"
  type        = string
  default     = "v1.10.6"
}

variable "domain_external" {
  description = "External domain for public services"
  type        = string
}

variable "domain_internal" {
  description = "Internal domain for private services"
  type        = string
}

variable "default_email" {
  description = "Default email for notifications and accounts"
  type        = string
}

variable "default_organization" {
  description = "Default organization name"
  type        = string
}
