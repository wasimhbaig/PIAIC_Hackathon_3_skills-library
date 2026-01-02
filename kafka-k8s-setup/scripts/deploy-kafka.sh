#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-"kafka"}
BROKER_COUNT=${BROKER_COUNT:-3}
HELM_TIMEOUT=${HELM_TIMEOUT:-"10m"}

echo "=== Deploying Kafka on Kubernetes ==="
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

# Deploy Kafka
echo ""
echo "3. Deploying Kafka cluster with $BROKER_COUNT brokers..."
if helm status kafka -n "$NAMESPACE" &> /dev/null; then
    echo "   ⚠ Kafka already installed, upgrading..."
    helm upgrade kafka bitnami/kafka \
        -n "$NAMESPACE" \
        --timeout "$HELM_TIMEOUT" \
        -f helm/kafka/values.yaml \
        --set replicaCount="$BROKER_COUNT"
else
    helm install kafka bitnami/kafka \
        -n "$NAMESPACE" \
        --timeout "$HELM_TIMEOUT" \
        -f helm/kafka/values.yaml \
        --set replicaCount="$BROKER_COUNT"
fi
echo "   ✓ Kafka Helm release deployed"

# Wait for Kafka brokers
echo ""
echo "4. Waiting for Kafka brokers to be ready..."
kubectl wait --namespace "$NAMESPACE" \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=kafka \
    --timeout=600s
echo "   ✓ All Kafka brokers are ready"

# Wait for Zookeeper
echo ""
echo "5. Waiting for Zookeeper to be ready..."
kubectl wait --namespace "$NAMESPACE" \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=zookeeper \
    --timeout=300s
echo "   ✓ Zookeeper ensemble is ready"

echo ""
echo "=== Kafka Deployment Complete ==="
echo ""
echo "Deployment details:"
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=kafka
echo ""
kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=kafka
echo ""
echo "Connection string (internal):"
echo "  kafka.$NAMESPACE.svc.cluster.local:9092"
echo ""
echo "Next steps:"
echo "  - Run ./scripts/create-topics.sh to create topics"
echo "  - Run ./scripts/verify-kafka.sh to verify deployment"
