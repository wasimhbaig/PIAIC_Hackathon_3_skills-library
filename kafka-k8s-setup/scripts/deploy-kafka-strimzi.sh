#!/bin/bash
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

NAMESPACE=${NAMESPACE:-"kafka"}
STRIMZI_VERSION=${STRIMZI_VERSION:-"0.43.0"}

echo "=== Deploying Kafka with Strimzi Operator ==="
echo ""

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Create namespace
echo "1. Creating namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "   ✓ Namespace ready"

# Install Strimzi operator
echo ""
echo "2. Installing Strimzi Kafka Operator (version $STRIMZI_VERSION)..."
kubectl create -f "https://github.com/strimzi/strimzi-kafka-operator/releases/download/$STRIMZI_VERSION/strimzi-cluster-operator-$STRIMZI_VERSION.yaml" -n "$NAMESPACE" 2>/dev/null || \
    kubectl apply -f "https://github.com/strimzi/strimzi-kafka-operator/releases/download/$STRIMZI_VERSION/strimzi-cluster-operator-$STRIMZI_VERSION.yaml" -n "$NAMESPACE"
echo "   ✓ Strimzi operator installed"

# Wait for operator to be ready
echo ""
echo "3. Waiting for Strimzi operator to be ready..."
kubectl wait --namespace "$NAMESPACE" \
    --for=condition=ready pod \
    --selector=name=strimzi-cluster-operator \
    --timeout=300s
echo "   ✓ Strimzi operator is ready"

# Deploy Kafka cluster
echo ""
echo "4. Deploying Kafka cluster..."
kubectl apply -f "$SKILL_DIR/strimzi/kafka-cluster.yaml" -n "$NAMESPACE"
echo "   ✓ Kafka cluster resource created"

# Wait for Kafka cluster
echo ""
echo "5. Waiting for Kafka cluster to be ready (this may take a few minutes)..."
echo "   Waiting for ZooKeeper..."
kubectl wait --namespace "$NAMESPACE" \
    --for=condition=ready pod \
    --selector=strimzi.io/name=learning-platform-kafka-zookeeper \
    --timeout=600s
echo "   ✓ ZooKeeper is ready"

echo ""
echo "   Waiting for Kafka brokers..."
kubectl wait --namespace "$NAMESPACE" \
    --for=condition=ready pod \
    --selector=strimzi.io/name=learning-platform-kafka-kafka \
    --timeout=600s
echo "   ✓ Kafka brokers are ready"

# Wait for Entity Operator (manages topics and users)
echo ""
echo "6. Waiting for Entity Operator..."
kubectl wait --namespace "$NAMESPACE" \
    --for=condition=ready pod \
    --selector=strimzi.io/name=learning-platform-kafka-entity-operator \
    --timeout=300s
echo "   ✓ Entity Operator is ready"

echo ""
echo "=== Kafka Deployment Complete ==="
echo ""
echo "Deployment details:"
kubectl get pods -n "$NAMESPACE" -l strimzi.io/cluster=learning-platform-kafka
echo ""
kubectl get svc -n "$NAMESPACE" -l strimzi.io/cluster=learning-platform-kafka
echo ""
echo "Kafka cluster name: learning-platform-kafka"
echo "Connection (internal): learning-platform-kafka-kafka-bootstrap.$NAMESPACE.svc.cluster.local:9092"
echo ""
echo "Next steps:"
echo "  - Run ./scripts/create-topics-strimzi.sh to create topics"
echo "  - Run ./scripts/verify-kafka.sh to verify deployment"
