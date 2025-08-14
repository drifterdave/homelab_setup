# 1Password CLI Commands

Quick reference for creating Kubernetes node entries using 1Password CLI.

## Prerequisites

```bash
# Set your 1Password service account token
export OP_SERVICE_ACCOUNT_TOKEN="your-1password-token"

# Verify connection
op vault list
```

## Multiple Nodes (Recommended)

Use the automated script to create multiple nodes:

```bash
# Edit configuration in scripts/create-1password-nodes.sh
NUM_CONTROL_NODES=2
NUM_WORKER_NODES=2
PROXMOX_NODE="pve-left"
CONTROL_NODE_START_IP="172.16.1.30"
WORKER_NODE_START_IP="172.16.1.40"

# Run the script
./scripts/create-1password-nodes.sh
```

This will create:
- `talos-control1` (172.16.1.30)
- `talos-control2` (172.16.1.31)
- `talos-worker1` (172.16.1.40)
- `talos-worker2` (172.16.1.41)

## Single Control Plane Node

```bash
op item create \
  --category=Server \
  --title="talos-control1" \
  --vault="Homelab" \
  --tags=kubernetes \
  "inputs.description[text]=Kubernetes control plane node 1" \
  "inputs.node_type[text]=control" \
  "inputs.private_ipv4[text]=172.16.1.30/24" \
  "inputs.cpu_cores[text]=2" \
  "inputs.memory_mb[text]=4096" \
  "inputs.disk_size_gb[text]=20" \
  "inputs.network_bridge[text]=vmbr0" \
  "inputs.datastore[text]=local-lvm" \
  "inputs.gateway[text]=172.16.1.1" \
  "inputs.proxmox_node[text]=pve-left" \
  "inputs.mac_address[text]=bc:24:11:1a:2b:3c"
```

## Single Worker Node

```bash
op item create \
  --category=Server \
  --title="talos-worker1" \
  --vault="Homelab" \
  --tags=kubernetes \
  "inputs.description[text]=Kubernetes worker node 1" \
  "inputs.node_type[text]=worker" \
  "inputs.private_ipv4[text]=172.16.1.40/24" \
  "inputs.cpu_cores[text]=4" \
  "inputs.memory_mb[text]=8192" \
  "inputs.disk_size_gb[text]=50" \
  "inputs.network_bridge[text]=vmbr0" \
  "inputs.datastore[text]=local-lvm" \
  "inputs.gateway[text]=172.16.1.1" \
  "inputs.proxmox_node[text]=pve-left" \
  "inputs.mac_address[text]=bc:24:11:5e:6f:7g"
```

## Service Entry

```bash
op item create \
  --category=Server \
  --title="nginx" \
  --vault="Services" \
  "inputs.description[text]=Web server" \
  "inputs.kubernetes_namespace[text]=default" \
  "inputs.kubernetes_replicas[text]=2" \
  "inputs.kubernetes_image[text]=nginx:alpine" \
  "inputs.kubernetes_port[text]=80" \
  "inputs.url[text]=web.example.com"
```

## DNS Record

```bash
op item create \
  --category=Server \
  --title="dns-example.com-web" \
  --vault="Homelab" \
  --tags=dns \
  "inputs.content[text]=192.168.1.100" \
  "inputs.type[text]=A" \
  "inputs.ttl[text]=300" \
  "inputs.comment[text]=Web server"
```

## Using the Script

```bash
# Run the automated script
./scripts/create-1password-nodes.sh
```

## Verification

```bash
# List all items in Homelab vault
op item list --vault Homelab

# List items with kubernetes tag
op item list --vault Homelab --tags kubernetes

# Get details of a specific item
op item get "talos-control-pve1" --vault Homelab
```

## Customization

To customize the entries, modify the values in the commands:

- **IP Addresses**: Change `172.16.1.10` and `172.16.1.11` to your desired IPs
- **Proxmox Node**: Change `pve1` to your actual Proxmox node name
- **Resources**: Adjust `cpu_cores`, `memory_mb`, `disk_size_gb` as needed
- **Network**: Update `network_bridge`, `datastore`, `gateway` for your setup
- **MAC Addresses**: Use deterministic MAC addresses (bc:24:11:xx:xx:xx format) with Proxmox OUI to prevent router flooding during testing

## Next Steps

After creating the entries:

1. **Update main.tf**:
   ```hcl
   data "onepassword_item" "example_kubernetes_node" {
     count = 1  # Change from 0 to 1
     vault = var.onepassword_homelab_vault
     title = "talos-control-pve1"  # Update to match your entry
   }
   ```

2. **Deploy infrastructure**:
   ```bash
   mise apply
   ```
