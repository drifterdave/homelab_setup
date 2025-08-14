#!/bin/bash

# Advanced script to automatically detect and update existing 1Password Kubernetes node entries with MAC addresses
# Usage: ./scripts/update-1password-mac-addresses-auto.sh

set -e

# Configuration
VAULT_NAME="Homelab"

echo "🔍 Automatically detecting and updating 1Password entries with MAC addresses..."

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
    
    # Check if the item already has a MAC address
    local existing_mac=$(op item get "$node_title" --vault="$VAULT_NAME" --format=json 2>/dev/null | jq -r '.fields[] | select(.label == "mac_address") | .value' 2>/dev/null || echo "")
    
    if [ -n "$existing_mac" ] && [ "$existing_mac" != "null" ]; then
        echo "  ℹ️  Node already has MAC address: $existing_mac"
        if [ "$existing_mac" = "$mac_address" ]; then
            echo "  ✅ MAC address matches expected value, skipping..."
        else
            echo "  ⚠️  MAC address differs from expected value"
            echo "     Expected: $mac_address"
            echo "     Current:  $existing_mac"
            read -p "     Update to expected MAC? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "  🔄 Updating MAC address..."
                op item edit "$node_title" \
                  --vault="$VAULT_NAME" \
                  "inputs.mac_address[text]=$mac_address"
                echo "  ✅ Updated $node_title with MAC $mac_address"
            else
                echo "  ⏭️  Skipping update..."
            fi
        fi
    else
        echo "  ➕ Adding MAC address..."
        op item edit "$node_title" \
          --vault="$VAULT_NAME" \
          "inputs.mac_address[text]=$mac_address"
        echo "  ✅ Added MAC $mac_address to $node_title"
    fi
    
    echo ""
}

# Function to detect node type from 1Password entry
detect_node_type() {
    local node_title=$1
    local node_type=$(op item get "$node_title" --vault="$VAULT_NAME" --format=json 2>/dev/null | jq -r '.fields[] | select(.label == "node_type") | .value' 2>/dev/null || echo "")
    
    if [ -n "$node_type" ] && [ "$node_type" != "null" ]; then
        echo "$node_type"
    else
        # Fallback: try to detect from title
        if [[ "$node_title" == *"control"* ]]; then
            echo "control"
        elif [[ "$node_title" == *"worker"* ]]; then
            echo "worker"
        else
            echo "unknown"
        fi
    fi
}

# Get all Kubernetes nodes from 1Password
echo "📋 Discovering existing Kubernetes nodes..."

# Get all items with kubernetes tag
kubernetes_items=$(op item list --vault="$VAULT_NAME" --tags=kubernetes --format=json 2>/dev/null | jq -r '.[].title' 2>/dev/null || echo "")

if [ -z "$kubernetes_items" ]; then
    echo "❌ No Kubernetes nodes found in vault '$VAULT_NAME'"
    echo "   Make sure your nodes have the 'kubernetes' tag"
    exit 1
fi

# Convert to array - handle multi-line output properly
NODES=()
while IFS= read -r line; do
    if [ -n "$line" ]; then
        NODES+=("$line")
    fi
done <<< "$kubernetes_items"

echo "Found ${#NODES[@]} Kubernetes nodes:"
for node in "${NODES[@]}"; do
    node_type=$(detect_node_type "$node")
    echo "  - $node ($node_type)"
done
echo ""

# Confirm before proceeding
echo "This will update all discovered nodes with MAC addresses."
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Operation cancelled"
    exit 0
fi

echo ""

# Update each node
updated_count=0
skipped_count=0
error_count=0

for node in "${NODES[@]}"; do
    if [ -n "$node" ]; then
        node_type=$(detect_node_type "$node")
        
        if [ "$node_type" = "unknown" ]; then
            echo "⚠️  Skipping $node (unknown node type)"
            ((skipped_count++))
            continue
        fi
        
        if update_node_mac "$node" "$node_type"; then
            ((updated_count++))
        else
            ((error_count++))
        fi
    fi
done

echo "🎉 MAC address update complete!"
echo ""
echo "📊 Summary:"
echo "   - Total nodes found: ${#NODES[@]}"
echo "   - Successfully updated: $updated_count"
echo "   - Skipped: $skipped_count"
echo "   - Errors: $error_count"
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
