#!/bin/bash
set -e

echo "=== Kubernetes Cluster Health Check ==="
echo ""

# Check kubectl connectivity
echo "1. Checking kubectl connectivity..."
if kubectl cluster-info &> /dev/null; then
    echo "   ✓ Cluster is reachable"
else
    echo "   ✗ Cannot connect to cluster"
    exit 1
fi

# Check nodes
echo ""
echo "2. Checking node status..."
NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || true)
echo "   Total nodes: $NODES"
echo "   Ready nodes: $READY_NODES"

if [ "$NODES" -eq "$READY_NODES" ]; then
    echo "   ✓ All nodes are ready"
else
    echo "   ⚠ Some nodes are not ready"
    kubectl get nodes
fi

# Check core DNS
echo ""
echo "3. Checking CoreDNS..."
DNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | wc -l)
if [ "$DNS_PODS" -gt 0 ]; then
    echo "   ✓ CoreDNS is running ($DNS_PODS pods)"
else
    echo "   ✗ CoreDNS not found"
fi

# Check storage classes
echo ""
echo "4. Checking storage classes..."
STORAGE_CLASSES=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)
if [ "$STORAGE_CLASSES" -gt 0 ]; then
    echo "   ✓ Storage classes available: $STORAGE_CLASSES"
    kubectl get storageclass
else
    echo "   ⚠ No storage classes found"
fi

# Check namespaces
echo ""
echo "5. Checking namespaces..."
kubectl get namespaces

echo ""
echo "=== Cluster Health Check Complete ==="
