#!/bin/bash
# Script to enable MariaDB High Availability by labeling worker nodes

set -e

echo "=== MariaDB HA Setup ==="
echo ""
echo "This script will:"
echo "1. Label worker nodes to allow MariaDB pods to spread"
echo "2. Scale MariaDB back to 3 replicas"
echo ""

# Check if KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
    export KUBECONFIG=~/.kube/config.local
fi

# Get worker nodes
WORKERS=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name" | grep -v control-plane || true)

if [ -z "$WORKERS" ]; then
    echo "ERROR: No worker nodes found!"
    exit 1
fi

echo "Found worker nodes:"
echo "$WORKERS"
echo ""

# Label worker nodes
echo "Labeling worker nodes with openstack-role=control-plane..."
for node in $WORKERS; do
    echo "  Labeling $node..."
    kubectl label node $node openstack-role=control-plane --overwrite
done

echo ""
echo "✅ Worker nodes labeled successfully"
echo ""

# Check current MariaDB replicas
CURRENT_REPLICAS=$(kubectl get statefulset mariadb-server -n openstack -o jsonpath='{.spec.replicas}')
echo "Current MariaDB replicas: $CURRENT_REPLICAS"

if [ "$CURRENT_REPLICAS" -eq 1 ]; then
    echo ""
    read -p "Scale MariaDB to 3 replicas now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Scaling MariaDB to 3 replicas..."
        kubectl scale statefulset mariadb-server -n openstack --replicas=3
        
        echo ""
        echo "Waiting for pods to be ready..."
        kubectl wait --for=condition=ready pod/mariadb-server-0 -n openstack --timeout=60s || true
        kubectl wait --for=condition=ready pod/mariadb-server-1 -n openstack --timeout=120s || true
        kubectl wait --for=condition=ready pod/mariadb-server-2 -n openstack --timeout=120s || true
        
        echo ""
        echo "MariaDB pod status:"
        kubectl get pods -n openstack -l application=mariadb
        
        echo ""
        echo "✅ MariaDB scaled to 3 replicas"
    else
        echo "Skipping scale operation"
    fi
else
    echo "MariaDB already has $CURRENT_REPLICAS replicas"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To verify MariaDB cluster status:"
echo "  kubectl exec mariadb-server-0 -n openstack -c mariadb -- mariadb -uroot -ppassword -e \"SHOW STATUS LIKE 'wsrep_%';\""
