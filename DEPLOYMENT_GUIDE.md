# Deployment Guide

This guide explains the two-phase deployment process to avoid Kubernetes connection issues.

## Problem

The original setup tried to connect to Kubernetes before the VMs were created, causing a "connection refused" error. This happens because:

1. Terraform tries to initialize the Kubernetes provider
2. The provider looks for `./kubeconfig` file
3. The file doesn't exist because the cluster isn't created yet
4. Provider defaults to `localhost:80` and fails

## Solution: Two-Phase Deployment

### Phase 1: Infrastructure Provisioning

**Goal**: Create VMs and bootstrap the Kubernetes cluster

**What happens**:
- Proxmox VMs are created with Talos Linux
- Talos schematic is generated and image downloaded
- Kubernetes cluster is bootstrapped
- No Kubernetes resources are created yet

**Files used**:
- `main.tf` (with Kubernetes providers commented out)
- `kubernetes-nodes.tf`
- `variables.tf`
- `outputs.tf`

**Commands**:
```bash
# Phase 1: Deploy infrastructure only
mise apply
```

### Phase 2: Kubernetes Resources

**Goal**: Deploy Kubernetes resources after cluster is ready

**What happens**:
- Kubernetes providers are enabled
- CoreDNS and services are deployed
- DNS records are created

**Steps**:
1. **Get kubeconfig** from the control plane node:
   ```bash
   # Get kubeconfig from control plane
   talosctl --nodes <control-plane-ip> config endpoint <control-plane-ip>
   talosctl --nodes <control-plane-ip> config node <control-plane-ip>
   talosctl --nodes <control-plane-ip> kubeconfig
   ```

2. **Enable Kubernetes providers** in `main.tf`:
   ```hcl
   provider "kubernetes" {
     config_path = "./kubeconfig"
   }

   provider "helm" {
     kubernetes {
       config_path = "./kubeconfig"
     }
   }
   ```

3. **Enable Kubernetes resources** in `dns.tf` and `services.tf`:
   - Uncomment all the Kubernetes resources
   - Remove the `# NOTE:` comments

4. **Deploy Kubernetes resources**:
   ```bash
   # Phase 2: Deploy Kubernetes resources
   mise apply
   ```

## Complete Workflow

### Step 1: Initial Setup
```bash
# Set environment variables
export OP_SERVICE_ACCOUNT_TOKEN="your-1password-token"

# Create 1Password items (see setup-example.md)
# Update terraform.auto.tfvars with your domains
```

### Step 2: Phase 1 - Infrastructure
```bash
# Deploy infrastructure only
mise apply

# Verify VMs are created in Proxmox
# Wait for Talos to boot and cluster to be ready
```

### Step 3: Get Kubernetes Access
```bash
# Get kubeconfig from control plane
talosctl --nodes 172.16.1.10 config endpoint 172.16.1.10
talosctl --nodes 172.16.1.10 config node 172.16.1.10
talosctl --nodes 172.16.1.10 kubeconfig

# Verify cluster access
kubectl get nodes
```

### Step 4: Phase 2 - Kubernetes Resources
```bash
# Enable Kubernetes providers and resources
# Edit main.tf, dns.tf, and services.tf

# Deploy Kubernetes resources
mise apply
```

## Verification

### After Phase 1
- ✅ Proxmox VMs created
- ✅ Talos image downloaded
- ✅ Kubernetes cluster bootstrapped
- ✅ Control plane accessible

### After Phase 2
- ✅ CoreDNS deployed
- ✅ Services deployed
- ✅ DNS records created
- ✅ Ingress working

## Troubleshooting

### Common Issues

1. **"connection refused" error**
   - **Cause**: Trying to connect to Kubernetes before cluster is ready
   - **Solution**: Follow the two-phase deployment process

2. **"kubeconfig not found" error**
   - **Cause**: kubeconfig file doesn't exist
   - **Solution**: Generate kubeconfig from control plane node

3. **"provider not found" error**
   - **Cause**: Kubernetes providers not enabled
   - **Solution**: Uncomment provider blocks in main.tf

4. **"resource not found" error**
   - **Cause**: Kubernetes resources not enabled
   - **Solution**: Uncomment resources in dns.tf and services.tf

### Debugging Commands

```bash
# Check VM status
kubectl get nodes

# Check cluster health
kubectl get componentstatuses

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check services
kubectl get services --all-namespaces
```

## Automation

For automated deployment, you can create scripts:

```bash
#!/bin/bash
# deploy-phase1.sh
echo "Phase 1: Deploying infrastructure..."
mise apply

echo "Waiting for cluster to be ready..."
sleep 60

echo "Getting kubeconfig..."
talosctl --nodes 172.16.1.10 config endpoint 172.16.1.10
talosctl --nodes 172.16.1.10 config node 172.16.1.10
talosctl --nodes 172.16.1.10 kubeconfig

echo "Phase 1 complete!"
```

```bash
#!/bin/bash
# deploy-phase2.sh
echo "Phase 2: Deploying Kubernetes resources..."
# Enable providers and resources first
mise apply

echo "Phase 2 complete!"
```

This approach ensures a clean, reliable deployment without connection issues.
