#!/bin/bash
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

NAMESPACE=${NAMESPACE:-"kafka"}
CLUSTER_NAME="learning-platform-kafka"

echo "=== Creating Kafka Topics with Strimzi ==="
echo ""

# Apply topic resources
echo "1. Creating topic resources..."

# Student events topic
cat <<EOF | kubectl apply -n "$NAMESPACE" -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: student-events
  labels:
    strimzi.io/cluster: $CLUSTER_NAME
spec:
  partitions: 3
  replicas: 2
  config:
    retention.ms: 604800000  # 7 days
    segment.ms: 86400000     # 1 day
EOF
echo "   ✓ Created topic: student-events"

# Course updates topic
cat <<EOF | kubectl apply -n "$NAMESPACE" -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: course-updates
  labels:
    strimzi.io/cluster: $CLUSTER_NAME
spec:
  partitions: 3
  replicas: 2
  config:
    retention.ms: 2592000000  # 30 days
EOF
echo "   ✓ Created topic: course-updates"

# Assessment results topic
cat <<EOF | kubectl apply -n "$NAMESPACE" -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: assessment-results
  labels:
    strimzi.io/cluster: $CLUSTER_NAME
spec:
  partitions: 5
  replicas: 2
  config:
    retention.ms: 7776000000  # 90 days
EOF
echo "   ✓ Created topic: assessment-results"

# Analytics stream topic
cat <<EOF | kubectl apply -n "$NAMESPACE" -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: analytics-stream
  labels:
    strimzi.io/cluster: $CLUSTER_NAME
spec:
  partitions: 5
  replicas: 2
  config:
    retention.ms: 259200000    # 3 days
    cleanup.policy: delete
EOF
echo "   ✓ Created topic: analytics-stream"

echo ""
echo "2. Waiting for topics to be ready..."
sleep 5

echo ""
echo "3. Listing created topics..."
kubectl get kafkatopic -n "$NAMESPACE" -l strimzi.io/cluster=$CLUSTER_NAME

echo ""
echo "=== Topic Creation Complete ==="
echo ""
echo "Created topics:"
echo "  - student-events (3 partitions, RF=2, 7 day retention)"
echo "  - course-updates (3 partitions, RF=2, 30 day retention)"
echo "  - assessment-results (5 partitions, RF=2, 90 day retention)"
echo "  - analytics-stream (5 partitions, RF=2, 3 day retention)"
