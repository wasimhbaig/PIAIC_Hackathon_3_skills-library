# PostgreSQL Kubernetes Setup

Deploy PostgreSQL on Kubernetes with automated schema migrations and verification for stateful data storage in microservices architectures.

## Purpose

Autonomously deploy a production-ready PostgreSQL database on Kubernetes, run database migrations, and verify schema integrity for persistent data storage in learning platform applications.

## Components

### Scripts

- **deploy-postgres.sh**: Deploys PostgreSQL using Helm with Bitnami chart
- **run-migrations.sh**: Executes database schema migrations
- **verify-postgres.sh**: Verifies PostgreSQL deployment, connectivity, and schema

### Helm Configuration

- **postgresql/values.yaml**: PostgreSQL configuration (replication, persistence, authentication)

### Migrations

- **migrations/**: SQL migration files for learning platform schema

## Prerequisites

- Kubernetes cluster with sufficient resources (minimum 2GB memory, 1 CPU core)
- `kubectl` configured with cluster access
- `helm` v3+ installed
- Storage class available for persistent volumes
- Cluster-admin or namespace-admin permissions

## Usage

### 1. Deploy PostgreSQL

```bash
./scripts/deploy-postgres.sh
```

This will:
- Add Bitnami Helm repository
- Deploy PostgreSQL with read replicas
- Configure persistent storage
- Set up authentication
- Wait for database to be ready

### 2. Run Migrations

```bash
./scripts/run-migrations.sh
```

Creates schema for:
- Users and authentication
- Courses and content
- Assessments and submissions
- Analytics and metrics

### 3. Verify Deployment

```bash
./scripts/verify-postgres.sh
```

Validates:
- PostgreSQL pods are running
- Database connectivity on port 5432
- Migrations applied successfully
- Schema integrity
- Read/write operations

## Database Schema

### Learning Platform Tables

**users**
- Student and instructor profiles
- Authentication credentials
- Preferences and settings

**courses**
- Course metadata and structure
- Content organization
- Enrollment tracking

**assessments**
- Quiz and assignment definitions
- Grading rubrics
- Submission tracking

**student_progress**
- Learning progress tracking
- Content completion status
- Performance metrics

**analytics_events**
- User activity logging
- Platform usage metrics
- Event stream archive

## Configuration

Edit `helm/postgresql/values.yaml` to customize:
- Authentication (passwords, users)
- Replication (primary + replicas)
- Resource limits and requests
- Persistence settings
- Connection pooling

## Architecture

```
┌────────────────────────────────────────┐
│      PostgreSQL Cluster (K8s)          │
│                                        │
│  ┌─────────────┐                       │
│  │   Primary   │  ← Read/Write         │
│  │  PostgreSQL │                       │
│  └──────┬──────┘                       │
│         │ Replication                  │
│    ┌────┴────┐                         │
│    │         │                         │
│  ┌─▼──┐   ┌─▼──┐                       │
│  │Rep1│   │Rep2│  ← Read-only          │
│  └────┘   └────┘                       │
│                                        │
│  Persistent Volume (PVC)               │
└────────────────────────────────────────┘
```

## Connection Details

**Internal (from within cluster):**
```
Host: postgres-postgresql.postgres.svc.cluster.local
Port: 5432
Database: learning_platform
User: postgres
```

**From application:**
```bash
postgresql://postgres:password@postgres-postgresql.postgres.svc.cluster.local:5432/learning_platform
```

## Migrations

Migrations are versioned SQL files in `migrations/` directory:

```
migrations/
├── V1__initial_schema.sql
├── V2__add_courses.sql
├── V3__add_assessments.sql
└── V4__add_analytics.sql
```

Each migration:
- Is idempotent (safe to run multiple times)
- Includes rollback instructions
- Is version controlled
- Creates or updates schema

## Backup and Recovery

### Create backup
```bash
kubectl exec -n postgres postgres-postgresql-0 -- pg_dump -U postgres learning_platform > backup.sql
```

### Restore from backup
```bash
cat backup.sql | kubectl exec -i -n postgres postgres-postgresql-0 -- psql -U postgres learning_platform
```

## Troubleshooting

### Pod not starting
```bash
kubectl describe pod -n postgres postgres-postgresql-0
kubectl logs -n postgres postgres-postgresql-0
```

### Connection refused
```bash
kubectl exec -n postgres postgres-postgresql-0 -- psql -U postgres -c "SELECT version();"
```

### Migration failures
```bash
kubectl exec -n postgres postgres-postgresql-0 -- psql -U postgres -d learning_platform -c "\dt"
```

## Cleanup

```bash
helm uninstall postgres -n postgres
kubectl delete pvc -n postgres data-postgres-postgresql-0
kubectl delete namespace postgres
```

## Performance Tuning

For production workloads:
- Increase `shared_buffers` to 25% of memory
- Configure `max_connections` based on workload
- Enable connection pooling (PgBouncer)
- Use read replicas for analytics queries
- Configure `work_mem` for complex queries
- Enable query logging and slow query analysis
