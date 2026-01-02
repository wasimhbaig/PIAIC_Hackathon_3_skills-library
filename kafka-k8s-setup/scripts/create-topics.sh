#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-"kafka"}
BROKER="kafka.${NAMESPACE}.svc.cluster.local:9092"

echo "=== Creating Kafka Topics ==="
echo ""

# Wait for Kafka to be ready
echo "1. Checking Kafka availability..."
kubectl exec -n "$NAMESPACE" kafka-0 -- kafka-broker-api-versions.sh --bootstrap-server localhost:9092 &> /dev/null
echo "   ✓ Kafka is available"

# Create topics
echo ""
echo "2. Creating topics..."

# Student events topic
echo "   Creating topic: student-events"
kubectl exec -n "$NAMESPACE" kafka-0 -- kafka-topics.sh \
    --create \
    --if-not-exists \
    --bootstrap-server localhost:9092 \
    --topic student-events \
    --partitions 3 \
    --replication-factor 2 \
    --config retention.ms=604800000 \
    --config segment.ms=86400000

# Course updates topic
echo "   Creating topic: course-updates"
kubectl exec -n "$NAMESPACE" kafka-0 -- kafka-topics.sh \
    --create \
    --if-not-exists \
    --bootstrap-server localhost:9092 \
    --topic course-updates \
    --partitions 3 \
    --replication-factor 2 \
    --config retention.ms=2592000000

# Assessment results topic
echo "   Creating topic: assessment-results"
kubectl exec -n "$NAMESPACE" kafka-0 -- kafka-topics.sh \
    --create \
    --if-not-exists \
    --bootstrap-server localhost:9092 \
    --topic assessment-results \
    --partitions 5 \
    --replication-factor 2 \
    --config retention.ms=7776000000

# Analytics stream topic
echo "   Creating topic: analytics-stream"
kubectl exec -n "$NAMESPACE" kafka-0 -- kafka-topics.sh \
    --create \
    --if-not-exists \
    --bootstrap-server localhost:9092 \
    --topic analytics-stream \
    --partitions 5 \
    --replication-factor 2 \
    --config retention.ms=259200000 \
    --config cleanup.policy=delete

echo ""
echo "3. Listing all topics..."
kubectl exec -n "$NAMESPACE" kafka-0 -- kafka-topics.sh \
    --list \
    --bootstrap-server localhost:9092

echo ""
echo "4. Describing created topics..."
for topic in student-events course-updates assessment-results analytics-stream; do
    echo ""
    echo "Topic: $topic"
    kubectl exec -n "$NAMESPACE" kafka-0 -- kafka-topics.sh \
        --describe \
        --bootstrap-server localhost:9092 \
        --topic "$topic"
done

echo ""
echo "=== Topic Creation Complete ==="
echo ""
echo "Created topics:"
echo "  - student-events (3 partitions, RF=2, 7 day retention)"
echo "  - course-updates (3 partitions, RF=2, 30 day retention)"
echo "  - assessment-results (5 partitions, RF=2, 90 day retention)"
echo "  - analytics-stream (5 partitions, RF=2, 3 day retention)"
