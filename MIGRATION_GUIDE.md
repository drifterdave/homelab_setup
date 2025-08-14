# Migration Guide

This guide helps you migrate from the old complex setup to the new simplified infrastructure.

## Overview of Changes

### What's Simplified

1. **File Structure**: Reduced from 15+ Terraform files to 5 core files
2. **Discovery Logic**: Removed complex discovery/processing/sync patterns
3. **Configuration**: Simplified variable structure and provider setup
4. **Workflow**: Streamlined 1Password integration
5. **Documentation**: Consolidated and simplified documentation

### What's Preserved

1. **1Password Integration**: All secret management remains in 1Password
2. **Talos Schematic Generation**: Custom image creation with extensions
3. **Image Factory URLs**: Automatic image URL retrieval
4. **Kubernetes Services**: Service deployment on Kubernetes
5. **DNS Management**: CoreDNS for service discovery

## Migration Steps

### 1. Backup Current State

```bash
# Backup current Terraform state
cp terraform.tfstate terraform.tfstate.backup
cp terraform.tfstate.backup terraform.tfstate.backup.old

# Backup current configuration
cp terraform.auto.tfvars terraform.auto.tfvars.backup
```

### 2. Update 1Password Structure

#### Providers Entry
Ensure your `providers` entry in the Homelab vault has these sections:

```
Title: providers
Vault: Homelab

Sections:
- proxmox: endpoint, username, password, api_token, insecure
- tailscale: api_key, tailnet
```

#### Kubernetes Nodes
Update your Kubernetes node entries:

**Old Format**:
```
Title: talos-control-pve1
Vault: Homelab
Sections: inputs, outputs
```

**New Format**:
```
Title: talos-control-pve1
Vault: Homelab
Tags: kubernetes
Sections: inputs, outputs
```

**Required Input Fields**:
- `description`: Human-readable description
- `node_type`: "control" or "worker"
- `private_ipv4`: Static IP address (e.g., "172.16.1.10/24")
- `cpu_cores`: Number of CPU cores
- `memory_mb`: Memory in MB
- `disk_size_gb`: Disk size in GB
- `network_bridge`: Proxmox network bridge
- `datastore`: Proxmox datastore
- `gateway`: Network gateway
- `proxmox_node`: Proxmox node name

#### Services
Update your service entries:

**Old Format**:
```
Title: kubernetes-nginx
Vault: Services
Sections: inputs, outputs
```

**New Format**:
```
Title: nginx
Vault: Services
Sections: inputs, outputs
```

**Required Input Fields**:
- `description`: Service description
- `kubernetes_namespace`: Kubernetes namespace
- `kubernetes_replicas`: Number of replicas
- `kubernetes_image`: Docker image
- `kubernetes_port`: Container port
- `url`: External URL for ingress

#### DNS Records
Update your DNS entries:

**Old Format**:
```
Title: dns-excloo.com-mail
Vault: Homelab
Sections: inputs, outputs
```

**New Format**:
```
Title: dns-excloo.com-mail
Vault: Homelab
Tags: dns
Sections: inputs, outputs
```

**Required Input Fields**:
- `content`: Record content (IP, hostname, etc.)
- `type`: Record type (A, CNAME, MX, TXT, etc.)
- `priority`: Priority for MX records (optional)
- `ttl`: Time to live (default: 300)
- `proxied`: Whether record is proxied (default: false)
- `wildcard`: Whether to create wildcard record (default: false)
- `comment`: Description of the record

### 3. Update Configuration

#### Variables
Update `terraform.auto.tfvars`:

```hcl
# Essential variables
default_email        = "admin@example.com"
default_organization = "My Homelab"
domain_external     = "example.com"
domain_internal     = "internal.example"
```

#### Environment Variables
Set your 1Password service account token:

```bash
export OP_SERVICE_ACCOUNT_TOKEN="your-1password-token"
```

### 4. Initialize New Setup

```bash
# Initialize new setup
tofu init

# Review the plan
tofu plan

# Apply changes
tofu apply
```

## Key Differences

### File Structure

**Old Structure** (Removed):
```
kubernetes.tf
kubernetes_discovery.tf
kubernetes_processing.tf
kubernetes_sync.tf
kubernetes_deployments.tf
services_discovery.tf
services_processing.tf
services_sync.tf
dns_discovery.tf
dns_processing.tf
coredns.tf
locals_dns.tf
providers.tf
terraform.tf
backend.tf
ARCHITECTURE.md
SECRETS.md
AGENTS.md
.mise.toml
.mise.local.toml
scripts/setup-proxmox.sh
examples/*.md (obsolete)
```

**New Structure**:
```
main.tf              # Core configuration, providers, discovery
kubernetes-nodes.tf  # Kubernetes node management
services.tf          # Service deployment
dns.tf              # DNS management
variables.tf        # Configuration variables
outputs.tf          # Output values
templates/          # Talos and CoreDNS templates
examples/setup-example.md
MIGRATION_GUIDE.md
README.md
```

### Discovery Pattern

**Old Pattern**:
```hcl
# Discovery
data "onepassword_items" "kubernetes" { ... }
locals { kubernetes_discovered = ... }

# Processing
locals { kubernetes_processed = ... }

# Sync
resource "onepassword_item" "kubernetes" { ... }
```

**New Pattern**:
```hcl
# Simple discovery and processing
data "onepassword_items" "kubernetes_nodes" { ... }
locals { kubernetes_nodes = ... }

# Direct resource creation
resource "proxmox_virtual_environment_vm" "kubernetes_nodes" { ... }
```

### Talos Configuration

**Old Pattern**:
- Complex template generation with multiple variables
- Separate control plane and worker configurations
- Manual certificate management

**New Pattern**:
- Simplified template with essential variables
- Automatic schematic generation
- Built-in certificate management

## Troubleshooting

### Common Migration Issues

1. **1Password Tags Missing**
   - Ensure Kubernetes nodes have `kubernetes` tag
   - Ensure DNS records have `dns` tag

2. **Provider Configuration**
   - Verify all required fields in `providers` entry
   - Check API tokens and endpoints

3. **State Conflicts**
   - Use `tofu import` for existing resources
   - Or start fresh with `tofu destroy` (use with caution)

4. **Template Variables**
   - Ensure all required variables are set in `terraform.auto.tfvars`
   - Check template syntax in Talos configurations

### Rollback Plan

If migration fails:

1. **Restore Backup**:
   ```bash
   cp terraform.tfstate.backup terraform.tfstate
   cp terraform.auto.tfvars.backup terraform.auto.tfvars
   ```

2. **Restore Old Files**:
   - Restore from git history or backup
   - Revert 1Password changes

3. **Reinitialize**:
   ```bash
   tofu init
   tofu plan
   tofu apply
   ```

## Benefits of New Setup

1. **Simplified Maintenance**: Fewer files, clearer structure
2. **Better Performance**: Reduced complexity in discovery logic
3. **Easier Debugging**: Direct resource creation without intermediate steps
4. **Improved Reliability**: Less moving parts, fewer failure points
5. **Better Documentation**: Clearer examples and workflows
6. **Cleaner Codebase**: Removed obsolete files and configurations

## Support

If you encounter issues during migration:

1. Check the troubleshooting section above
2. Review the new README.md for updated workflows
3. Compare your 1Password structure with the examples
4. Verify all required variables are set correctly
5. Check the setup example in `examples/setup-example.md`
