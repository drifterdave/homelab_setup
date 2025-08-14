#!/bin/bash

# Script to verify MAC addresses in 1Password Kubernetes node entries
# Usage: ./scripts/verify-mac-addresses.sh

set -e

# Configuration
VAULT_NAME="Homelab"

echo "🔍 Verifying MAC addresses in 1Password entries..."

# Function to generate expected MAC address
generate_mac() {
    local node_name=$1
    local node_type=$2
    
    # Create a hash of the node name for consistency
    local hash=$(echo "$node_name" | md5sum | cut -c1-6)
    
    # Use Proxmox OUI (bc:24:11) with hash for uniqueness
    # This makes MAC addresses look authentic to Proxmox VMs
    echo "bc:24:11:${hash:0:2}:${hash:2:2}:${hash:4:2}"
}

# Function to verify a single node entry
verify_node_mac() {
    local node_title=$1
    local node_type=$2
    
    echo "Checking node: $node_title"
    
    # Get current MAC address from 1Password
    local current_mac=$(op item get "$node_title" --vault="$VAULT_NAME" --format=json 2>/dev/null | jq -r '.fields[] | select(.label == "mac_address") | .value' 2>/dev/null || echo "")
    
    # Generate expected MAC address
    local expected_mac=$(generate_mac "$node_title" "$node_type")
    
    if [ -z "$current_mac" ] || [ "$current_mac" = "null" ]; then
        echo "  ❌ No MAC address found"
        echo "     Expected: $expected_mac"
        echo "     Status:   Missing"
    elif [ "$current_mac" = "$expected_mac" ]; then
        echo "  ✅ MAC address matches expected value"
        echo "     MAC:      $current_mac"
        echo "     Status:   Correct"
    else
        echo "  ⚠️  MAC address differs from expected value"
        echo "     Expected: $expected_mac"
        echo "     Current:  $current_mac"
        echo "     Status:   Mismatch"
    fi
    
    echo ""
}

# Get all Kubernetes nodes from 1Password
echo "📋 Discovering Kubernetes nodes..."

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
    echo "  - $node"
done
echo ""

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

# Verify each node
correct_count=0
missing_count=0
mismatch_count=0

for node in "${NODES[@]}"; do
    if [ -n "$node" ]; then
        node_type=$(detect_node_type "$node")
        
        if [ "$node_type" = "unknown" ]; then
            echo "⚠️  Skipping $node (unknown node type)"
            continue
        fi
        
        # Get current MAC address
        current_mac=$(op item get "$node" --vault="$VAULT_NAME" --format=json 2>/dev/null | jq -r '.fields[] | select(.label == "mac_address") | .value' 2>/dev/null || echo "")
        expected_mac=$(generate_mac "$node" "$node_type")
        
        if [ -z "$current_mac" ] || [ "$current_mac" = "null" ]; then
            ((missing_count++))
        elif [ "$current_mac" = "$expected_mac" ]; then
            ((correct_count++))
        else
            ((mismatch_count++))
        fi
        
        verify_node_mac "$node" "$node_type"
    fi
done

echo "🎉 MAC address verification complete!"
echo ""
echo "📊 Summary:"
echo "   - Total nodes checked: ${#NODES[@]}"
echo "   - Correct MAC addresses: $correct_count"
echo "   - Missing MAC addresses: $missing_count"
echo "   - Mismatched MAC addresses: $mismatch_count"
echo ""

if [ $missing_count -gt 0 ] || [ $mismatch_count -gt 0 ]; then
    echo "⚠️  Issues found!"
    echo "   Run one of these scripts to fix:"
    echo "   - ./scripts/update-1password-mac-addresses.sh (manual)"
    echo "   - ./scripts/update-1password-mac-addresses-auto.sh (automatic)"
else
    echo "✅ All MAC addresses are correct!"
    echo "   Your VMs will retain consistent MAC addresses across recreations."
fi

echo ""
