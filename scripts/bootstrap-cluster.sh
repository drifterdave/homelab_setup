#!/bin/bash

# Script to bootstrap the Kubernetes cluster after VMs are ready
# Usage: ./scripts/bootstrap-cluster.sh

set -e

echo "🚀 Bootstrapping Kubernetes cluster..."

# Configuration
CONTROL_PLANE_NODES=("172.16.1.30" "172.16.1.31")
FIRST_CONTROL_NODE="172.16.1.30"

echo "📋 Checking Talos nodes..."

# Check if Talos nodes are reachable
for node in "${CONTROL_PLANE_NODES[@]}"; do
    echo "  Checking $node..."
    if ! ping -c 1 -W 5 "$node" >/dev/null 2>&1; then
        echo "  ❌ Node $node is not reachable"
        echo "     Make sure VMs are running and have the correct IP addresses"
        exit 1
    fi
    echo "  ✅ Node $node is reachable"
done

echo ""
echo "🔧 Generating Talos client configuration..."

# Generate Talos client configuration
if [ ! -f "config/talosconfig" ]; then
    echo "  Creating config/talosconfig..."
    mkdir -p config
    
    # Get the client configuration from Terraform
    tofu output -json talos_client_config > config/talosconfig
    echo "  ✅ Created config/talosconfig"
else
    echo "  ✅ config/talosconfig already exists"
fi

echo ""
echo "⏳ Waiting for Talos API to be ready..."

# Wait for Talos API to be ready on the first control plane node
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    echo "  Attempt $attempt/$max_attempts: Checking Talos API on $FIRST_CONTROL_NODE..."
    
    if timeout 10s talosctl --config config/talosconfig --nodes "$FIRST_CONTROL_NODE" version >/dev/null 2>&1; then
        echo "  ✅ Talos API is ready on $FIRST_CONTROL_NODE"
        break
    fi
    
    if [ $attempt -eq $max_attempts ]; then
        echo "  ❌ Talos API is not ready after $max_attempts attempts"
        echo "     Please check the VM console and ensure Talos is running properly"
        exit 1
    fi
    
    echo "  ⏳ Waiting 10 seconds before next attempt..."
    sleep 10
    ((attempt++))
done

echo ""
echo "🔍 Checking cluster status..."

# Check if cluster is already bootstrapped
if talosctl --config config/talosconfig --nodes "$FIRST_CONTROL_NODE" health --control-plane-nodes "$FIRST_CONTROL_NODE" >/dev/null 2>&1; then
    echo "  ✅ Cluster is already bootstrapped"
    echo ""
    echo "🎉 Cluster is ready!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Get the kubeconfig:"
    echo "   talosctl --config config/talosconfig --nodes $FIRST_CONTROL_NODE kubeconfig"
    echo ""
    echo "2. Test the cluster:"
    echo "   kubectl get nodes"
    echo ""
    exit 0
fi

echo "  ℹ️  Cluster is not bootstrapped yet"
echo ""
echo "🚀 Bootstrapping cluster..."

# Bootstrap the cluster
if talosctl --config config/talosconfig --nodes "$FIRST_CONTROL_NODE" bootstrap; then
    echo "  ✅ Bootstrap successful"
else
    echo "  ❌ Bootstrap failed"
    echo "     Check the VM console for any errors"
    exit 1
fi

echo ""
echo "⏳ Waiting for cluster to be ready..."

# Wait for cluster to be ready
max_attempts=60
attempt=1

while [ $attempt -le $max_attempts ]; do
    echo "  Attempt $attempt/$max_attempts: Checking cluster health..."
    
    if talosctl --config config/talosconfig --nodes "$FIRST_CONTROL_NODE" health --control-plane-nodes "$FIRST_CONTROL_NODE" >/dev/null 2>&1; then
        echo "  ✅ Cluster is healthy"
        break
    fi
    
    if [ $attempt -eq $max_attempts ]; then
        echo "  ❌ Cluster is not ready after $max_attempts attempts"
        echo "     Check the VM console for any errors"
        exit 1
    fi
    
    echo "  ⏳ Waiting 10 seconds before next attempt..."
    sleep 10
    ((attempt++))
done

echo ""
echo "🎉 Cluster bootstrap complete!"
echo ""
echo "📋 Next steps:"
echo "1. Get the kubeconfig:"
echo "   talosctl --config config/talosconfig --nodes $FIRST_CONTROL_NODE kubeconfig"
echo ""
echo "2. Test the cluster:"
echo "   kubectl get nodes"
echo ""
echo "3. Check node status:"
echo "   talosctl --config config/talosconfig --nodes $FIRST_CONTROL_NODE health"
echo ""
