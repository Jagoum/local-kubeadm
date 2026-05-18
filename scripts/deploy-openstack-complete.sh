#!/bin/bash
# Complete OpenStack Deployment Script
# This script ensures all services deploy correctly with proper configuration

set -e

echo "========================================="
echo "  OpenStack Complete Deployment Script  "
echo "========================================="
echo ""

# Set kubeconfig
if [ -z "$KUBECONFIG" ]; then
    export KUBECONFIG=~/.kube/config.local
fi

echo "Using KUBECONFIG: $KUBECONFIG"
echo ""

# Step 1: Label worker nodes for MariaDB HA
echo "Step 1: Labeling worker nodes for MariaDB High Availability"
echo "-----------------------------------------------------------"
WORKERS=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name" | grep -v control-plane || true)

if [ -z "$WORKERS" ]; then
    echo "⚠️  WARNING: No worker nodes found!"
    echo "   MariaDB will run all replicas on control-plane node"
    echo "   This may cause volume attachment issues"
    echo ""
else
    echo "Found worker nodes:"
    for node in $WORKERS; do
        echo "  - $node"
        kubectl label node $node openstack-role=control-plane --overwrite
    done
    echo "✅ Worker nodes labeled successfully"
    echo ""
fi

# Step 2: Apply updated ArgoCD applications via Terraform
echo "Step 2: Applying ArgoCD application configurations"
echo "---------------------------------------------------"
cd "$(dirname "$0")/../terraform/bootstrap"

echo "Running terraform apply..."
terraform apply -auto-approve

echo "✅ ArgoCD applications updated"
echo ""

# Step 3: Wait for MariaDB to be healthy
echo "Step 3: Waiting for MariaDB cluster to be healthy"
echo "--------------------------------------------------"
echo "Waiting for MariaDB pods..."
kubectl wait --for=condition=ready pod/mariadb-server-0 -n openstack --timeout=180s || echo "⚠️  Timeout waiting for mariadb-server-0"
kubectl wait --for=condition=ready pod/mariadb-server-1 -n openstack --timeout=180s || echo "⚠️  Timeout waiting for mariadb-server-1"
kubectl wait --for=condition=ready pod/mariadb-server-2 -n openstack --timeout=180s || echo "⚠️  Timeout waiting for mariadb-server-2"

echo ""
echo "MariaDB pod status:"
kubectl get pods -n openstack -l application=mariadb

echo ""
echo "Checking MariaDB cluster status..."
kubectl exec mariadb-server-0 -n openstack -c mariadb -- mariadb -uroot -ppassword -e "SHOW STATUS LIKE 'wsrep_%';" 2>/dev/null | grep -E "wsrep_cluster_size|wsrep_local_state_comment|wsrep_ready" || echo "⚠️  Could not check cluster status"

echo ""
echo "✅ MariaDB cluster check complete"
echo ""

# Step 4: Monitor Keystone deployment
echo "Step 4: Monitoring Keystone deployment"
echo "---------------------------------------"
echo "Waiting for Keystone jobs to complete..."
sleep 10

echo ""
echo "Keystone job status:"
kubectl get jobs -n openstack -l application=keystone 2>/dev/null || echo "No Keystone jobs found yet"

echo ""
echo "Keystone pod status:"
kubectl get pods -n openstack -l application=keystone

echo ""
echo "✅ Keystone deployment initiated"
echo ""

# Step 5: Check overall ArgoCD sync status
echo "Step 5: Checking ArgoCD application sync status"
echo "------------------------------------------------"
kubectl get applications -n argocd

echo ""
echo "========================================="
echo "  Deployment Complete!                  "
echo "========================================="
echo ""
echo "Next Steps:"
echo "1. Monitor ArgoCD applications: kubectl get applications -n argocd"
echo "2. Check pod status: kubectl get pods -n openstack"
echo "3. View ArgoCD UI for detailed sync status"
echo ""
echo "If services are still failing:"
echo "- Check logs: kubectl logs -n openstack <pod-name>"
echo "- Check events: kubectl get events -n openstack --sort-by='.lastTimestamp'"
echo "- Review documentation: docs/KEYSTONE_BOOTSTRAP_ISSUE.md"
echo ""
