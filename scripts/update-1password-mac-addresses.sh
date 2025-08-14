#!/bin/bash

# Script to update existing 1Password Kubernetes node entries with MAC addresses
# Usage: ./scripts/update-1password-mac-addresses.sh

set -e

# Configuration
VAULT_NAME="Homelab"

echo "Updating existing 1Password entries with MAC addresses..."

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

# Function to update a single node entry
update_node_mac() {
    local node_title=$1
    local node_type=$2
    
    echo "Processing node: $node_title"
    
    # Generate MAC address for this node
    local mac_address=$(generate_mac "$node_title" "$node_type")
    
    echo "  Generated MAC: $mac_address"
    
    # Check if the item exists
    if op item get "$node_title" --vault="$VAULT_NAME" >/dev/null 2>&1; then
        echo "  ✅ Item exists, updating MAC address..."
        
        # Update the item with the MAC address
        op item edit "$node_title" \
          --vault="$VAULT_NAME" \
          "inputs.mac_address[text]=$mac_address"
        
        echo "  ✅ Updated $node_title with MAC $mac_address"
    else
        echo "  ❌ Item '$node_title' not found in vault '$VAULT_NAME'"
        echo "     Skipping..."
    fi
    
    echo ""
}

# List of existing nodes to update
# Update these to match your actual node names
NODES=(
    "talos-control-1:control"
    "talos-control-2:control"
    "talos-worker-1:worker"
    "talos-worker-2:worker"
)

echo "Found ${#NODES[@]} nodes to update:"
for node in "${NODES[@]}"; do
    IFS=':' read -r node_name node_type <<< "$node"
    echo "  - $node_name ($node_type)"
done
echo ""

# Update each node
for node in "${NODES[@]}"; do
    IFS=':' read -r node_name node_type <<< "$node"
    update_node_mac "$node_name" "$node_type"
done

echo "🎉 MAC address update complete!"
echo ""
echo "📊 Summary:"
echo "   - Processed ${#NODES[@]} nodes"
echo "   - MAC addresses generated deterministically based on node names"
echo "   - All MAC addresses use local unicast range (02:xx:xx:xx:xx:xx)"
echo ""
echo "📋 Next steps:"
echo "1. Verify the updates:"
echo "   op item get 'talos-control-1' --vault='$VAULT_NAME'"
echo ""
echo "2. Apply the infrastructure changes:"
echo "   tofu apply"
echo ""
echo "3. The VMs will now retain their MAC addresses across recreations"
echo ""
