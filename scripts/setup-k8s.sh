#!/bin/bash
# ============================================================================
# Kubernetes Setup Script
# =======================
# 
# This script sets up all Kubernetes resources for the bioinformatics platform
#
# WHAT IT DOES:
# 1. Creates namespace
# 2. Sets up RBAC (ServiceAccount, Role, RoleBinding)
# 3. Creates storage (PVC)
# 4. Sets resource quotas
#
# DEVOPS ANALOGY:
# Like running Terraform apply - sets up infrastructure
#
# USAGE:
#   bash scripts/setup-k8s.sh
#
# REQUIREMENTS:
#   - kubectl configured and connected to cluster
#   - Cluster admin permissions
#   - EFS/Filestore already created (for storage)
#
# ============================================================================

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
K8S_DIR="$(dirname "$0")/../k8s"
NAMESPACE="bioinformatics"

# ============================================================================
# FUNCTIONS
# ============================================================================

print_header() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           Kubernetes Setup for Bioinformatics Platform       ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
        exit 1
    fi
    
    print_info "✓ kubectl installed and connected"
    
    # Show cluster info
    print_info "Cluster: $(kubectl config current-context)"
    print_info "Server: $(kubectl cluster-info | grep 'Kubernetes control plane' | awk '{print $NF}')"
}

create_namespace() {
    print_step "Creating namespace: $NAMESPACE"
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_info "Namespace $NAMESPACE already exists"
    else
        kubectl apply -f "$K8S_DIR/namespace.yaml"
        print_info "✓ Namespace created"
    fi
}

setup_rbac() {
    print_step "Setting up RBAC (ServiceAccount, Role, RoleBinding)..."
    
    kubectl apply -f "$K8S_DIR/rbac.yaml"
    
    # Verify
    if kubectl get serviceaccount nextflow-sa -n $NAMESPACE &> /dev/null; then
        print_info "✓ ServiceAccount created"
    else
        print_error "Failed to create ServiceAccount"
        exit 1
    fi
    
    if kubectl get role nextflow-role -n $NAMESPACE &> /dev/null; then
        print_info "✓ Role created"
    else
        print_error "Failed to create Role"
        exit 1
    fi
    
    if kubectl get rolebinding nextflow-rolebinding -n $NAMESPACE &> /dev/null; then
        print_info "✓ RoleBinding created"
    else
        print_error "Failed to create RoleBinding"
        exit 1
    fi
}

setup_storage() {
    print_step "Setting up storage (StorageClass, PVC)..."
    
    # Check if EFS/Filestore is configured
    print_info "⚠️  Make sure to update fileSystemId in k8s/storage.yaml with your EFS ID"
    
    kubectl apply -f "$K8S_DIR/storage.yaml"
    
    # Wait for PVC to be bound (with timeout)
    print_info "Waiting for PVC to be bound (this may take a minute)..."
    
    timeout=120
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        status=$(kubectl get pvc genomics-data-pvc -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
        
        if [ "$status" == "Bound" ]; then
            print_info "✓ PVC bound successfully"
            break
        elif [ "$status" == "NotFound" ]; then
            print_error "PVC not found"
            exit 1
        else
            echo -n "."
            sleep 5
            elapsed=$((elapsed + 5))
        fi
    done
    
    if [ $elapsed -ge $timeout ]; then
        print_error "Timeout waiting for PVC to be bound"
        print_info "Check PVC status: kubectl describe pvc genomics-data-pvc -n $NAMESPACE"
        exit 1
    fi
}

setup_resource_quota() {
    print_step "Setting up resource quotas..."
    
    kubectl apply -f "$K8S_DIR/resource-quota.yaml"
    
    # Show quota status
    print_info "Resource quota status:"
    kubectl describe resourcequota bioinformatics-quota -n $NAMESPACE
}

verify_setup() {
    print_step "Verifying setup..."
    
    echo ""
    echo "Namespace:"
    kubectl get namespace $NAMESPACE
    
    echo ""
    echo "ServiceAccount:"
    kubectl get serviceaccount nextflow-sa -n $NAMESPACE
    
    echo ""
    echo "Role:"
    kubectl get role nextflow-role -n $NAMESPACE
    
    echo ""
    echo "RoleBinding:"
    kubectl get rolebinding nextflow-rolebinding -n $NAMESPACE
    
    echo ""
    echo "PVC:"
    kubectl get pvc genomics-data-pvc -n $NAMESPACE
    
    echo ""
    echo "Resource Quota:"
    kubectl get resourcequota bioinformatics-quota -n $NAMESPACE
    
    echo ""
    print_info "✓ Setup complete!"
}

print_next_steps() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                        Next Steps                             ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "1. Upload reference genome and test data to PVC:"
    echo "   kubectl run -it --rm upload --image=busybox --restart=Never \\"
    echo "     --overrides='{\"spec\":{\"volumes\":[{\"name\":\"data\",\"persistentVolumeClaim\":{\"claimName\":\"genomics-data-pvc\"}}],\"containers\":[{\"name\":\"upload\",\"image\":\"busybox\",\"volumeMounts\":[{\"name\":\"data\",\"mountPath\":\"/data\"}]}]}}' \\"
    echo "     -n $NAMESPACE -- sh"
    echo ""
    echo "2. Run the pipeline:"
    echo "   bash scripts/run-pipeline.sh"
    echo ""
    echo "3. Monitor execution:"
    echo "   kubectl get pods -n $NAMESPACE -w"
    echo ""
    echo "4. View logs:"
    echo "   kubectl logs <pod-name> -n $NAMESPACE"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    print_header
    
    check_prerequisites
    create_namespace
    setup_rbac
    setup_storage
    setup_resource_quota
    verify_setup
    print_next_steps
}

# Run main function
main
