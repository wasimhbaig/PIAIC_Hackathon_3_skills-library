# Kafka Kubernetes Setup

Deploy Apache Kafka on Kubernetes with automated topic creation and connectivity verification.

## Purpose

Autonomously deploy a production-ready Kafka cluster on Kubernetes, create necessary topics, and verify end-to-end connectivity for event streaming in microservices architectures.

## Components

### Scripts

- **deploy-kafka.sh**: Deploys Kafka cluster using Helm with Bitnami chart
- **create-topics.sh**: Creates Kafka topics with specified partitions and replication
- **verify-kafka.sh**: Verifies Kafka deployment, broker connectivity, and topic creation

### Helm Configuration

- **kafka/values.yaml**: Kafka cluster configuration (brokers, zookeeper, persistence)

## Prerequisites

- Kubernetes cluster with sufficient resources (minimum 6GB memory, 3 CPU cores)
- `kubectl` configured with cluster access
- `helm` v3+ installed
- Storage class available for persistent volumes
- Cluster-admin or namespace-admin permissions

## Usage

### 1. Deploy Kafka Cluster

```bash
./scripts/deploy-kafka.sh
```

This will:
- Add Bitnami Helm repository
- Deploy Kafka with Zookeeper
- Configure 3 broker replicas
- Set up persistent storage
- Wait for all pods to be ready

### 2. Create Topics

```bash
./scripts/create-topics.sh
```

Default topics created:
- `student-events`: Student activity events (3 partitions, RF=2)
- `course-updates`: Course content updates (3 partitions, RF=2)
- `assessment-results`: Assessment and grading events (5 partitions, RF=2)
- `analytics-stream`: Analytics and metrics stream (5 partitions, RF=2)

### 3. Verify Deployment

```bash
./scripts/verify-kafka.sh
```

Validates:
- Kafka broker pods are running
- Zookeeper ensemble is healthy
- Broker connectivity on port 9092
- Topics created successfully
- Producer/consumer connectivity

## Configuration

Edit `helm/kafka/values.yaml` to customize:
- Number of broker replicas
- Partition count and replication factor
- Resource limits and requests
- Persistence settings
- JVM heap sizes

## Architecture

```
┌─────────────────────────────────────────┐
│          Kafka Cluster (K8s)            │
│                                         │
│  ┌──────────┐  ┌──────────┐  ┌────────┐│
│  │ Broker 1 │  │ Broker 2 │  │Broker 3││
│  └────┬─────┘  └────┬─────┘  └───┬────┘│
│       │             │             │     │
│  ┌────┴─────────────┴─────────────┴───┐ │
│  │      Zookeeper Ensemble (3)        │ │
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## Topics Schema

| Topic | Partitions | Replication | Use Case |
|-------|-----------|-------------|----------|
| student-events | 3 | 2 | Student login, progress, interactions |
| course-updates | 3 | 2 | Course content changes, announcements |
| assessment-results | 5 | 2 | Quiz submissions, grades, feedback |
| analytics-stream | 5 | 2 | Real-time metrics and analytics |

## Troubleshooting

### Image Pull Errors
If you see `ImagePullBackOff` errors:
```bash
kubectl describe pod -n kafka kafka-controller-0
```

**Solution**: Update the image tag in `helm/kafka/values.yaml`:
```yaml
image:
  registry: docker.io
  repository: bitnami/kafka
  tag: "3.6.1"  # or use latest available version
```

Note: Bitnami changed image distribution policy (Aug 2025). Newer images may require subscription.

### Pods not starting
```bash
kubectl describe pods -n kafka -l app.kubernetes.io/name=kafka
kubectl logs -n kafka kafka-0
```

### Topic creation fails
```bash
kubectl exec -n kafka kafka-0 -- kafka-topics.sh --list --bootstrap-server localhost:9092
```

### Connectivity issues
```bash
kubectl exec -n kafka kafka-0 -- kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

## Cleanup

```bash
helm uninstall kafka -n kafka
kubectl delete pvc -n kafka -l app.kubernetes.io/name=kafka
kubectl delete namespace kafka
```

## Performance Tuning

For production workloads:
- Increase broker replicas to 5+
- Adjust `num.partitions` based on throughput needs
- Tune `log.retention.hours` for data retention
- Configure JVM heap (recommended: 4-6GB per broker)
- Use dedicated storage class with high IOPS
