# Homelab Infrastructure

Infrastructure as code for homelab management using OpenTofu, Proxmox, Talos Linux, and 1Password.

## Overview

This setup provides a simplified approach to managing your homelab infrastructure with the following key features:

- **1Password Integration**: Secure secret management for all configurations
- **Talos Linux**: Immutable Kubernetes nodes with custom schematics
- **Proxmox**: Virtual machine management
- **Kubernetes**: Container orchestration with automatic service deployment
- **DNS Management**: CoreDNS for service discovery and custom records

## Quick Start

### Prerequisites

- [1Password CLI](https://1password.com/downloads/command-line/) with service account
- [OpenTofu](https://opentofu.org/) 1.8+
- [Proxmox VE](https://www.proxmox.com/en/proxmox-ve) cluster
- [Tailscale](https://tailscale.com/) account and API key

### Setup

1. **Clone the repository**
   ```bash
   git clone <your-repo>
   cd homelab_setup
   ```

2. **Configure 1Password**
   Create a `providers` entry in your Homelab vault with the following sections:
   - `proxmox`: endpoint, username, password, api_token, insecure
   - `tailscale`: api_key, tailnet

3. **Set environment variables**
   ```bash
   export OP_SERVICE_ACCOUNT_TOKEN="your-1password-token"
   ```

4. **Update configuration**
   Edit `terraform.auto.tfvars` with your domain settings:
   ```hcl
   default_email        = "admin@example.com"
   default_organization = "My Homelab"
   domain_external     = "example.com"
   domain_internal     = "internal.example"
   ```

5. **Initialize and deploy**
   ```bash
   tofu init
   tofu plan
   tofu apply
   ```

## Configuration

### Variables (terraform.auto.tfvars)

```hcl
default_email        = "admin@example.com"
default_organization = "My Homelab"
domain_external     = "example.com"
domain_internal     = "internal.example"
```

### 1Password Structure

#### Homelab Vault

**Providers Entry** (required):
```
Title: providers
Vault: Homelab

Sections:
- proxmox: endpoint, username, password, api_token, insecure
- tailscale: api_key, tailnet
```

**Kubernetes Nodes**:
```
Title: talos-control-pve1 (or any name)
Vault: Homelab
Tags: kubernetes

Input Section:
- description: "Control plane node"
- node_type: "control" (or "worker")
- private_ipv4: "172.16.1.10/24"
- cpu_cores: "2"
- memory_mb: "4096"
- disk_size_gb: "20"
- network_bridge: "vmbr0"
- datastore: "local-lvm"
- gateway: "172.16.1.1"
- proxmox_node: "pve1"
```

**DNS Records**:
```
Title: dns-example.com-mail
Vault: Homelab
Tags: dns

Input Section:
- content: "192.168.1.100"
- type: "A"
- ttl: "300"
- comment: "Mail server"
```

#### Services Vault

**Services**:
```
Title: nginx (or any service name)
Vault: Services

Input Section:
- description: "Web server"
- kubernetes_namespace: "default"
- kubernetes_replicas: "2"
- kubernetes_image: "nginx:alpine"
- kubernetes_port: "80"
- url: "web.example.com"
```

## Workflow

### Adding Kubernetes Nodes

1. **Create entry** in 1Password Homelab vault with title `talos-{node_type}-{proxmox_node}`
2. **Add tags**: `kubernetes`
3. **Fill inputs**: node_type, private_ipv4, cpu_cores, memory_mb, etc.
4. **Run apply**: `tofu apply`

### Adding Services

1. **Create entry** in 1Password Services vault
2. **Fill inputs**: kubernetes_namespace, kubernetes_replicas, kubernetes_image, kubernetes_port, url
3. **Run apply**: `tofu apply`

### Adding DNS Records

1. **Create entry** in 1Password Homelab vault with title `dns-{zone}-{name}`
2. **Add tags**: `dns`
3. **Fill inputs**: content, type, ttl, comment
4. **Run apply**: `tofu apply`

## Architecture

### Talos Schematic Generation

The setup automatically generates a custom Talos Linux schematic with:
- Tailscale extension for zero-trust networking
- QEMU guest agent for Proxmox integration
- Custom system extensions as needed

### Image Factory Integration

- Uses `talos_image_factory_schematic` to create custom images
- Retrieves image URLs via `talos_image_factory_urls`
- Downloads images to Proxmox for VM creation

### Kubernetes Cluster

- **Control Plane**: Single or multiple control plane nodes
- **Worker Nodes**: Scalable worker nodes for workloads
- **Networking**: Flannel CNI with custom pod/service CIDRs
- **DNS**: CoreDNS for service discovery and custom records
- **Bootstrap**: Automatic bootstrap using Talos provider
- **Config Files**: Automatic generation of `config/talosconfig` and `config/kubeconfig`

### Service Deployment

- **Automatic**: Services are deployed based on 1Password entries
- **Ingress**: NGINX ingress controller with TLS termination
- **Namespaces**: Automatic namespace creation
- **Scaling**: Configurable replica counts

## Commands

```bash
tofu init      # Initialize OpenTofu
tofu plan      # Review changes
tofu apply     # Apply changes (creates VMs, bootstraps cluster, saves configs)
tofu destroy   # Clean up (use with caution)
```

## Security

- **Secrets**: All sensitive data stored in 1Password
- **Networking**: Tailscale for secure node communication
- **TLS**: Automatic certificate management via cert-manager
- **Access**: Kubernetes RBAC for service accounts

## Troubleshooting

### Common Issues

1. **1Password Connection**: Ensure `OP_SERVICE_ACCOUNT_TOKEN` is set
2. **Proxmox Access**: Verify API token and endpoint configuration
3. **Talos Boot**: Check network configuration and gateway settings
4. **Kubernetes Join**: Ensure control plane endpoint is accessible

### Logs

- **Talos**: Access via `talosctl` or Proxmox console
- **Kubernetes**: Use `kubectl logs` for pod debugging
- **CoreDNS**: Check CoreDNS pod logs for DNS issues

### Useful Commands

```bash
# View outputs
tofu output

# Check Talos schematic
tofu output talos_schematic_id

# Check image URL
tofu output talos_image_url

# List Kubernetes nodes
tofu output kubernetes_nodes

# List services
tofu output services

# Use generated configs
export KUBECONFIG=./config/kubeconfig
kubectl get nodes

# Use Talos config
talosctl --config config/talosconfig --nodes 172.16.1.30 health
```

## File Structure

```
├── main.tf              # Core configuration, providers, discovery
├── kubernetes-nodes.tf  # Kubernetes node management
├── services.tf          # Service deployment
├── dns.tf              # DNS management
├── variables.tf        # Configuration variables
├── outputs.tf          # Output values
├── templates/          # Talos and CoreDNS templates
│   ├── talos/
│   │   ├── controlplane.yaml
│   │   └── worker.yaml
│   └── coredns/
│       └── Corefile
├── examples/           # Usage examples
│   └── setup-example.md
└── MIGRATION_GUIDE.md  # Migration from old setup
```

## License

AGPL-3.0 - see [LICENSE](LICENSE)
