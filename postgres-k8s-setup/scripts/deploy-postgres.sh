#!/bin/bash
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

NAMESPACE=${NAMESPACE:-"postgres"}
DATABASE_NAME=${DATABASE_NAME:-"learning_platform"}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"postgres123"}
HELM_TIMEOUT=${HELM_TIMEOUT:-"10m"}
VALUES_FILE="$SKILL_DIR/helm/postgresql/values.yaml"

echo "=== Deploying PostgreSQL on Kubernetes ==="
echo ""

# Check prerequisites
if ! command -v helm &> /dev/null; then
    echo "Error: helm is not installed"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Create namespace
echo "1. Creating namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "   ✓ Namespace ready"

# Add Bitnami Helm repository
echo ""
echo "2. Adding Bitnami Helm repository..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
echo "   ✓ Helm repositories updated"

# Check values file exists
if [ ! -f "$VALUES_FILE" ]; then
    echo "Error: Values file not found: $VALUES_FILE"
    exit 1
fi

# Deploy PostgreSQL
echo ""
echo "3. Deploying PostgreSQL..."
echo "   Using values file: $VALUES_FILE"
if helm status postgres -n "$NAMESPACE" &> /dev/null; then
    echo "   ⚠ PostgreSQL already installed, upgrading..."
    helm upgrade postgres bitnami/postgresql \
        -n "$NAMESPACE" \
        --timeout "$HELM_TIMEOUT" \
        -f "$VALUES_FILE" \
        --set auth.postgresPassword="$POSTGRES_PASSWORD" \
        --set auth.database="$DATABASE_NAME"
else
    helm install postgres bitnami/postgresql \
        -n "$NAMESPACE" \
        --timeout "$HELM_TIMEOUT" \
        -f "$VALUES_FILE" \
        --set auth.postgresPassword="$POSTGRES_PASSWORD" \
        --set auth.database="$DATABASE_NAME"
fi
echo "   ✓ PostgreSQL Helm release deployed"

# Wait for PostgreSQL primary
echo ""
echo "4. Waiting for PostgreSQL primary to be ready..."
kubectl wait --namespace "$NAMESPACE" \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=primary \
    --timeout=300s
echo "   ✓ PostgreSQL primary is ready"

# Wait for read replicas if enabled
echo ""
echo "5. Checking for read replicas..."
REPLICA_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=read --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$REPLICA_COUNT" -gt 0 ]; then
    echo "   Waiting for read replicas..."
    kubectl wait --namespace "$NAMESPACE" \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=read \
        --timeout=300s || true
    echo "   ✓ Read replicas are ready"
else
    echo "   ℹ No read replicas configured"
fi

# Test connectivity
echo ""
echo "6. Testing database connectivity..."
if kubectl exec -n "$NAMESPACE" postgres-postgresql-0 -- psql -U postgres -c "SELECT version();" &> /dev/null; then
    echo "   ✓ Database is accessible"
else
    echo "   ✗ Cannot connect to database"
    exit 1
fi

echo ""
echo "=== PostgreSQL Deployment Complete ==="
echo ""
echo "Deployment details:"
kubectl get pods -n "$NAMESPACE"
echo ""
kubectl get svc -n "$NAMESPACE"
echo ""
echo "Connection details:"
echo "  Host: postgres-postgresql.$NAMESPACE.svc.cluster.local"
echo "  Port: 5432"
echo "  Database: $DATABASE_NAME"
echo "  User: postgres"
echo ""
echo "Connection string:"
echo "  postgresql://postgres:****@postgres-postgresql.$NAMESPACE.svc.cluster.local:5432/$DATABASE_NAME"
echo ""
echo "Next steps:"
echo "  - Run ./scripts/run-migrations.sh to apply schema"
echo "  - Run ./scripts/verify-postgres.sh to verify deployment"
