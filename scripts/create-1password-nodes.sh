#!/bin/bash

# 1Password CLI script to create Kubernetes node entries
# Usage: ./scripts/create-1password-nodes.sh

set -e

# Configuration
VAULT_NAME="Homelab"
CONTROL_NODE_START_IP="172.16.1.30"
WORKER_NODE_START_IP="172.16.1.40"
GATEWAY="172.16.1.1"
PROXMOX_NODE="pve-left"
CONTROL_NODE_PREFIX="talos-control-"
WORKER_NODE_PREFIX="talos-worker-"

NUM_CONTROL_NODES=2
NUM_WORKER_NODES=2

CONTROL_NODE_IP="$CONTROL_NODE_START_IP"
WORKER_NODE_IP="$WORKER_NODE_START_IP"

echo "Creating 1Password entries for Kubernetes nodes..."

# Function to increment IP address
increment_ip() {
    local ip=$1
    local increment=$2
    
    # Split IP into octets
    IFS='.' read -r -a octets <<< "$ip"
    
    # Convert to integer, increment, and convert back
    local last_octet=$((10#${octets[3]} + increment))
    
    # Handle overflow
    if [ $last_octet -gt 254 ]; then
        octets[2]=$((10#${octets[2]} + 1))
        last_octet=$((last_octet - 255))
    fi
    
    echo "${octets[0]}.${octets[1]}.${octets[2]}.$last_octet"
}

# Function to generate deterministic MAC address
generate_mac() {
    local node_name=$1
    local node_type=$2
    
    # Create a hash of the node name for consistency
    local hash=$(echo "$node_name" | md5sum | cut -c1-6)
    
    # Use Proxmox OUI (bc:24:11) with hash for uniqueness
    # This makes MAC addresses look authentic to Proxmox VMs
    echo "bc:24:11:${hash:0:2}:${hash:2:2}:${hash:4:2}"
}

# Create control plane nodes
echo "Creating $NUM_CONTROL_NODES control plane node(s)..."
for i in $(seq 1 $NUM_CONTROL_NODES); do
    current_ip=$(increment_ip "$CONTROL_NODE_START_IP" $((i-1)))
    node_title="${CONTROL_NODE_PREFIX}${i}"
    mac_address=$(generate_mac "$node_title" "control")
    
    echo "Creating control plane node $i: $node_title ($current_ip) with MAC $mac_address..."
    op item create \
      --category=Server \
      --title="$node_title" \
      --vault="$VAULT_NAME" \
      --tags=kubernetes \
      "inputs.description[text]=Kubernetes control plane node $i" \
      "inputs.node_type[text]=control" \
      "inputs.private_ipv4[text]=$current_ip/24" \
      "inputs.cpu_cores[text]=2" \
      "inputs.memory_mb[text]=4096" \
      "inputs.disk_size_gb[text]=20" \
      "inputs.network_bridge[text]=vmbr0" \
      "inputs.datastore[text]=local-lvm" \
      "inputs.gateway[text]=$GATEWAY" \
      "inputs.proxmox_node[text]=$PROXMOX_NODE" \
      "inputs.mac_address[text]=$mac_address"
    
    echo "✅ Control plane node $i created: $node_title"
done

# Create worker nodes
echo "Creating $NUM_WORKER_NODES worker node(s)..."
for i in $(seq 1 $NUM_WORKER_NODES); do
    current_ip=$(increment_ip "$WORKER_NODE_START_IP" $((i-1)))
    node_title="${WORKER_NODE_PREFIX}${i}"
    mac_address=$(generate_mac "$node_title" "worker")
    
    echo "Creating worker node $i: $node_title ($current_ip) with MAC $mac_address..."
    op item create \
      --category=Server \
      --title="$node_title" \
      --vault="$VAULT_NAME" \
      --tags=kubernetes \
      "inputs.description[text]=Kubernetes worker node $i" \
      "inputs.node_type[text]=worker" \
      "inputs.private_ipv4[text]=$current_ip/24" \
      "inputs.cpu_cores[text]=4" \
      "inputs.memory_mb[text]=8192" \
      "inputs.disk_size_gb[text]=50" \
      "inputs.network_bridge[text]=vmbr0" \
      "inputs.datastore[text]=local-lvm" \
      "inputs.gateway[text]=$GATEWAY" \
      "inputs.proxmox_node[text]=$PROXMOX_NODE" \
      "inputs.mac_address[text]=$mac_address"
    
    echo "✅ Worker node $i created: $node_title"
done

echo ""
echo "🎉 All Kubernetes node entries created successfully!"
echo ""
echo "📊 Summary:"
echo "   - Control plane nodes: $NUM_CONTROL_NODES"
echo "   - Worker nodes: $NUM_WORKER_NODES"
echo "   - Total nodes: $((NUM_CONTROL_NODES + NUM_WORKER_NODES))"
echo ""
echo "📋 Next steps:"
echo "1. Update the data sources in main.tf:"
echo "   - Change count = 0 to count = $((NUM_CONTROL_NODES + NUM_WORKER_NODES))"
echo "   - Update the titles to match your entries:"
for i in $(seq 1 $NUM_CONTROL_NODES); do
    echo "     - ${CONTROL_NODE_PREFIX}${i}"
done
for i in $(seq 1 $NUM_WORKER_NODES); do
    echo "     - ${WORKER_NODE_PREFIX}${i}"
done
echo "2. Run: mise apply"
echo ""
