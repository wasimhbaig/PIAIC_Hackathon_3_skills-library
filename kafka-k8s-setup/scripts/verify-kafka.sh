#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-"kafka"}
BROKER="localhost:9092"

echo "=== Kafka Deployment Verification ==="
echo ""

# Check Kafka pods
echo "1. Checking Kafka broker pods..."
KAFKA_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=kafka --no-headers 2>/dev/null | wc -l)
KAFKA_READY=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=kafka --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
echo "   Total Kafka pods: $KAFKA_PODS"
echo "   Running pods: $KAFKA_READY"

if [ "$KAFKA_PODS" -eq "$KAFKA_READY" ] && [ "$KAFKA_READY" -gt 0 ]; then
    echo "   ✓ All Kafka broker pods are running"
else
    echo "   ✗ Some Kafka pods are not running"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=kafka
    exit 1
fi

# Check Zookeeper pods
echo ""
echo "2. Checking Zookeeper ensemble..."
ZK_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=zookeeper --no-headers 2>/dev/null | wc -l)
ZK_READY=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=zookeeper --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
echo "   Total Zookeeper pods: $ZK_PODS"
echo "   Running pods: $ZK_READY"

if [ "$ZK_PODS" -eq "$ZK_READY" ] && [ "$ZK_READY" -gt 0 ]; then
    echo "   ✓ Zookeeper ensemble is healthy"
else
    echo "   ✗ Some Zookeeper pods are not running"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=zookeeper
    exit 1
fi

# Check broker connectivity
echo ""
echo "3. Checking broker connectivity..."
if kubectl exec -n "$NAMESPACE" kafka-0 -- kafka-broker-api-versions.sh --bootstrap-server "$BROKER" &> /dev/null; then
    echo "   ✓ Brokers are accessible on port 9092"
else
    echo "   ✗ Cannot connect to brokers"
    exit 1
fi

# List brokers
echo ""
echo "4. Listing Kafka brokers..."
kubectl exec -n "$NAMESPACE" kafka-0 -- kafka-broker-api-versions.sh --bootstrap-server "$BROKER" | head -5

# Check topics
echo ""
echo "5. Checking topics..."
TOPICS=$(kubectl exec -n "$NAMESPACE" kafka-0 -- kafka-topics.sh --list --bootstrap-server "$BROKER" 2>/dev/null)
TOPIC_COUNT=$(echo "$TOPICS" | grep -v "^$" | wc -l)
echo "   Total topics: $TOPIC_COUNT"

if [ "$TOPIC_COUNT" -gt 0 ]; then
    echo "   ✓ Topics created successfully"
    echo ""
    echo "   Available topics:"
    echo "$TOPICS" | sed 's/^/     - /'
else
    echo "   ⚠ No topics found (run create-topics.sh)"
fi

# Test producer/consumer
echo ""
echo "6. Testing producer/consumer connectivity..."
TEST_TOPIC="test-connectivity-$(date +%s)"

# Create test topic
kubectl exec -n "$NAMESPACE" kafka-0 -- kafka-topics.sh \
    --create \
    --if-not-exists \
    --bootstrap-server "$BROKER" \
    --topic "$TEST_TOPIC" \
    --partitions 1 \
    --replication-factor 1 &> /dev/null

# Produce test message
echo "test-message-$(date +%s)" | kubectl exec -i -n "$NAMESPACE" kafka-0 -- kafka-console-producer.sh \
    --bootstrap-server "$BROKER" \
    --topic "$TEST_TOPIC" &> /dev/null

# Consume test message
TEST_MSG=$(kubectl exec -n "$NAMESPACE" kafka-0 -- kafka-console-consumer.sh \
    --bootstrap-server "$BROKER" \
    --topic "$TEST_TOPIC" \
    --from-beginning \
    --max-messages 1 \
    --timeout-ms 5000 2>/dev/null || true)

# Delete test topic
kubectl exec -n "$NAMESPACE" kafka-0 -- kafka-topics.sh \
    --delete \
    --bootstrap-server "$BROKER" \
    --topic "$TEST_TOPIC" &> /dev/null || true

if [ -n "$TEST_MSG" ]; then
    echo "   ✓ Producer/consumer test successful"
else
    echo "   ✗ Producer/consumer test failed"
    exit 1
fi

# Check for errors in logs
echo ""
echo "7. Checking for errors in broker logs..."
ERROR_COUNT=$(kubectl logs -n "$NAMESPACE" kafka-0 --tail=100 2>/dev/null | grep -i "error\|exception" | wc -l || echo "0")
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo "   ✓ No errors found in recent logs"
else
    echo "   ⚠ Found $ERROR_COUNT error/exception messages in logs"
    echo "   Run: kubectl logs -n $NAMESPACE kafka-0 | grep -i error"
fi

echo ""
echo "=== Kafka Verification Complete ==="
echo ""
echo "Summary:"
echo "  ✓ Kafka brokers: $KAFKA_READY/$KAFKA_PODS running"
echo "  ✓ Zookeeper nodes: $ZK_READY/$ZK_PODS running"
echo "  ✓ Broker connectivity: OK"
echo "  ✓ Topics available: $TOPIC_COUNT"
echo "  ✓ Producer/Consumer: OK"
echo ""
echo "Kafka is ready for use!"
