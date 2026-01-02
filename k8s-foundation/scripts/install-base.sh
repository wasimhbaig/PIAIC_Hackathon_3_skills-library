#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-"default"}
HELM_TIMEOUT=${HELM_TIMEOUT:-"5m"}

echo "=== Installing Kubernetes Foundation Infrastructure ==="
echo ""

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "Error: helm is not installed"
    exit 1
fi

# Add helm repositories
echo "1. Adding Helm repositories..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
echo "   ✓ Helm repositories updated"

# Install Nginx Ingress Controller
echo ""
echo "2. Installing Nginx Ingress Controller..."
if helm status nginx-ingress -n ingress-nginx &> /dev/null; then
    echo "   ⚠ Nginx Ingress already installed, upgrading..."
    helm upgrade nginx-ingress ingress-nginx/ingress-nginx \
        -n ingress-nginx \
        --timeout "$HELM_TIMEOUT" \
        -f helm/nginx/values.yaml
else
    kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
    helm install nginx-ingress ingress-nginx/ingress-nginx \
        -n ingress-nginx \
        --create-namespace \
        --timeout "$HELM_TIMEOUT" \
        -f helm/nginx/values.yaml
fi
echo "   ✓ Nginx Ingress Controller installed"

# Create monitoring namespace
echo ""
echo "3. Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
echo "   ✓ Monitoring namespace ready"

# Wait for ingress controller
echo ""
echo "4. Waiting for Nginx Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s
echo "   ✓ Nginx Ingress Controller is ready"

echo ""
echo "=== Foundation Infrastructure Installation Complete ==="
echo ""
echo "Installed components:"
echo "  - Nginx Ingress Controller (namespace: ingress-nginx)"
echo "  - Monitoring namespace"
echo ""
echo "Next steps:"
echo "  - Deploy your applications"
echo "  - Configure ingress resources"
echo "  - Setup monitoring stack"
