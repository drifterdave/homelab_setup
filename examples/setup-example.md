# Setup Example

This example demonstrates how to set up the simplified homelab infrastructure.

## Prerequisites

1. **1Password CLI** installed and configured
2. **OpenTofu** 1.8+ installed
3. **Proxmox VE** cluster running
4. **Tailscale** account and API key

## Step 1: Configure 1Password

### Create Providers Entry

Create a new entry in your Homelab vault:

```
Title: providers
Vault: Homelab

Section: proxmox
- endpoint: https://pve.example.com:8006/api2/json
- username: root@pam
- password: your-proxmox-password
- api_token: your-proxmox-api-token
- insecure: false

Section: tailscale
- api_key: tskey-auth-...
- tailnet: your-tailnet.example.com
```

### Create Kubernetes Node Entry

Create a control plane node entry:

```
Title: talos-control-pve1
Vault: Homelab
Tags: kubernetes

Section: inputs
- description: "Kubernetes control plane node"
- node_type: "control"
- private_ipv4: "172.16.1.10/24"
- cpu_cores: "2"
- memory_mb: "4096"
- disk_size_gb: "20"
- network_bridge: "vmbr0"
- datastore: "local-lvm"
- gateway: "172.16.1.1"
- proxmox_node: "pve1"
```

Create a worker node entry:

```
Title: talos-worker-pve1
Vault: Homelab
Tags: kubernetes

Section: inputs
- description: "Kubernetes worker node"
- node_type: "worker"
- private_ipv4: "172.16.1.11/24"
- cpu_cores: "4"
- memory_mb: "8192"
- disk_size_gb: "50"
- network_bridge: "vmbr0"
- datastore: "local-lvm"
- gateway: "172.16.1.1"
- proxmox_node: "pve1"
```

### Create Service Entry

Create a service entry in your Services vault:

```
Title: nginx
Vault: Services

Section: inputs
- description: "Web server"
- kubernetes_namespace: "default"
- kubernetes_replicas: "2"
- kubernetes_image: "nginx:alpine"
- kubernetes_port: "80"
- url: "web.example.com"
```

### Create DNS Record Entry

Create a DNS record entry:

```
Title: dns-example.com-web
Vault: Homelab
Tags: dns

Section: inputs
- content: "192.168.1.100"
- type: "A"
- ttl: "300"
- comment: "Web server"
```

## Step 2: Configure Terraform

### Update terraform.auto.tfvars

```hcl
default_email        = "admin@example.com"
default_organization = "My Homelab"
domain_external     = "example.com"
domain_internal     = "internal.example"
```

### Set Environment Variables

```bash
export OP_SERVICE_ACCOUNT_TOKEN="your-1password-service-account-token"
```

## Step 3: Deploy Infrastructure

### Initialize OpenTofu

```bash
tofu init
```

### Review Plan

```bash
tofu plan
```

You should see:
- Talos schematic creation
- Proxmox VM creation for Kubernetes nodes
- Tailscale device creation
- 1Password item updates

### Apply Changes

```bash
tofu apply
```

## Step 4: Verify Deployment

### Check Kubernetes Nodes

```bash
# Get kubeconfig from control plane node
talosctl --nodes 172.16.1.10 config endpoint 172.16.1.10
talosctl --nodes 172.16.1.10 config node 172.16.1.10
talosctl --nodes 172.16.1.10 kubeconfig

# Check nodes
kubectl get nodes
```

### Check Services

```bash
# Check namespaces
kubectl get namespaces

# Check deployments
kubectl get deployments

# Check services
kubectl get services

# Check ingress
kubectl get ingress
```

### Check DNS

```bash
# Test DNS resolution
nslookup web.example.com
nslookup nginx.default.svc.internal.example
```

## Step 5: Access Services

### External Access

Your services will be available at:
- `https://web.example.com` (external)
- `http://nginx.internal.example` (internal)

### Internal Access

Services are also available within the cluster:
- `http://nginx.default.svc.cluster.local`

## Adding More Resources

### Add Another Worker Node

1. Create a new 1Password entry:
   ```
   Title: talos-worker-pve2
   Vault: Homelab
   Tags: kubernetes
   
   Section: inputs
   - description: "Second worker node"
   - node_type: "worker"
   - private_ipv4: "172.16.1.12/24"
   - cpu_cores: "4"
   - memory_mb: "8192"
   - disk_size_gb: "50"
   - network_bridge: "vmbr0"
   - datastore: "local-lvm"
   - gateway: "172.16.1.1"
   - proxmox_node: "pve2"
   ```

2. Apply changes:
   ```bash
   tofu apply
   ```

### Add Another Service

1. Create a new service entry:
   ```
   Title: grafana
   Vault: Services
   
   Section: inputs
   - description: "Monitoring dashboard"
   - kubernetes_namespace: "monitoring"
   - kubernetes_replicas: "1"
   - kubernetes_image: "grafana/grafana:latest"
   - kubernetes_port: "3000"
   - url: "grafana.example.com"
   ```

2. Apply changes:
   ```bash
   tofu apply
   ```

## Troubleshooting

### Common Issues

1. **1Password Connection**
   ```bash
   # Test 1Password connection
   op item list --vault Homelab
   ```

2. **Proxmox Connection**
   ```bash
   # Test Proxmox API
   curl -k -u root@pam:password https://pve.example.com:8006/api2/json/nodes
   ```

3. **Talos Boot Issues**
   ```bash
   # Check Talos boot logs
   talosctl --nodes 172.16.1.10 health
   ```

4. **Kubernetes Issues**
   ```bash
   # Check cluster status
   kubectl get componentstatuses
   kubectl get pods --all-namespaces
   ```

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
```

## Next Steps

1. **Install Ingress Controller**: Deploy NGINX ingress controller
2. **Setup Cert Manager**: For automatic TLS certificates
3. **Configure Monitoring**: Deploy Prometheus and Grafana
4. **Setup Backup**: Configure Velero for cluster backups
5. **Security Hardening**: Apply security policies and network policies
