#!/bin/bash
set -e

NAMESPACE=${NAMESPACE:-"postgres"}
DATABASE_NAME=${DATABASE_NAME:-"learning_platform"}

# Get PostgreSQL password from secret
POSTGRES_PASSWORD=$(kubectl get secret -n "$NAMESPACE" postgres-postgresql -o jsonpath='{.data.postgres-password}' 2>/dev/null | base64 -d)
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "Warning: Could not retrieve PostgreSQL password from secret, trying without password..."
    POSTGRES_PASSWORD=""
fi

echo "=== PostgreSQL Deployment Verification ==="
echo ""

# Check PostgreSQL primary pod
echo "1. Checking PostgreSQL primary pod..."
PRIMARY_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=primary --no-headers 2>/dev/null | wc -l)
PRIMARY_READY=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=primary --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
echo "   Total primary pods: $PRIMARY_PODS"
echo "   Running pods: $PRIMARY_READY"

if [ "$PRIMARY_READY" -eq 1 ]; then
    echo "   ✓ PostgreSQL primary pod is running"
else
    echo "   ✗ PostgreSQL primary pod is not running"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=primary
    exit 1
fi

# Check read replicas
echo ""
echo "2. Checking read replicas..."
REPLICA_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=read --no-headers 2>/dev/null | wc -l || echo "0")
REPLICA_READY=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=read --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo "0")
echo "   Total replica pods: $REPLICA_PODS"
echo "   Running replicas: $REPLICA_READY"

if [ "$REPLICA_PODS" -gt 0 ]; then
    if [ "$REPLICA_PODS" -eq "$REPLICA_READY" ]; then
        echo "   ✓ All read replicas are running"
    else
        echo "   ⚠ Some replicas are not running"
    fi
else
    echo "   ℹ No read replicas configured"
fi

# Check database connectivity
echo ""
echo "3. Checking database connectivity..."
if kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -c "SELECT 1;" &> /dev/null; then
    echo "   ✓ Database is accessible on port 5432"
else
    echo "   ✗ Cannot connect to database"
    exit 1
fi

# Check PostgreSQL version
echo ""
echo "4. Checking PostgreSQL version..."
PG_VERSION=$(kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -t -c "SELECT version();" | head -1)
echo "   PostgreSQL version: $PG_VERSION"

# Check database exists
echo ""
echo "5. Checking database: $DATABASE_NAME"
DB_EXISTS=$(kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
    env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -t -c "SELECT 1 FROM pg_database WHERE datname='$DATABASE_NAME';" | tr -d ' ')

if [ "$DB_EXISTS" = "1" ]; then
    echo "   ✓ Database '$DATABASE_NAME' exists"
else
    echo "   ✗ Database '$DATABASE_NAME' not found"
    exit 1
fi

# Check migrations
echo ""
echo "6. Checking applied migrations..."
MIGRATIONS_TABLE=$(kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
    env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d "$DATABASE_NAME" -t -c \
    "SELECT EXISTS (SELECT FROM pg_tables WHERE tablename = 'schema_migrations');" 2>/dev/null | tr -d ' ')

if [ "$MIGRATIONS_TABLE" = "t" ]; then
    MIGRATION_COUNT=$(kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
        env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d "$DATABASE_NAME" -t -c \
        "SELECT COUNT(*) FROM schema_migrations;" | tr -d ' ')
    echo "   ✓ Migrations table exists"
    echo "   Applied migrations: $MIGRATION_COUNT"

    if [ "$MIGRATION_COUNT" -gt 0 ]; then
        echo ""
        echo "   Recent migrations:"
        kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
            env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d "$DATABASE_NAME" -c \
            "SELECT version, applied_at FROM schema_migrations ORDER BY applied_at DESC LIMIT 5;"
    fi
else
    echo "   ⚠ No migrations table found (run run-migrations.sh)"
fi

# Check schema tables
echo ""
echo "7. Checking schema tables..."
TABLES=$(kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
    env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d "$DATABASE_NAME" -t -c \
    "SELECT tablename FROM pg_tables WHERE schemaname='public';" | grep -v "^$" || true)
TABLE_COUNT=$(echo "$TABLES" | grep -v "^$" | wc -l)

echo "   Total tables: $TABLE_COUNT"
if [ "$TABLE_COUNT" -gt 0 ]; then
    echo "   ✓ Schema tables exist"
    echo ""
    echo "   Tables:"
    echo "$TABLES" | sed 's/^/     - /'
else
    echo "   ℹ No tables found (run migrations to create schema)"
fi

# Test read operation
echo ""
echo "8. Testing SELECT query..."
if kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
    env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d "$DATABASE_NAME" -c "SELECT NOW();" &> /dev/null; then
    echo "   ✓ SELECT query successful"
else
    echo "   ✗ SELECT query failed"
    exit 1
fi

# Test write operation
echo ""
echo "9. Testing INSERT query..."
TEST_TABLE="test_connectivity_$(date +%s)"
kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
    env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d "$DATABASE_NAME" <<EOF &> /dev/null
CREATE TABLE $TEST_TABLE (id SERIAL PRIMARY KEY, value TEXT);
INSERT INTO $TEST_TABLE (value) VALUES ('test');
SELECT * FROM $TEST_TABLE;
DROP TABLE $TEST_TABLE;
EOF

if [ $? -eq 0 ]; then
    echo "   ✓ INSERT/CREATE/DROP queries successful"
else
    echo "   ✗ Write operations failed"
    exit 1
fi

# Check for errors in logs
echo ""
echo "10. Checking for errors in logs..."
ERROR_COUNT=$(kubectl logs -n "$NAMESPACE" postgres-postgresql-primary-0 --tail=100 2>/dev/null | grep -i "error\|fatal" | grep -v "FATAL:  role" | wc -l || echo "0")
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo "   ✓ No errors found in recent logs"
else
    echo "   ⚠ Found $ERROR_COUNT error/fatal messages in logs"
    echo "   Run: kubectl logs -n $NAMESPACE postgres-postgresql-primary-0 | grep -i error"
fi

# Check replication lag (if replicas exist)
if [ "$REPLICA_PODS" -gt 0 ]; then
    echo ""
    echo "11. Checking replication lag..."
    kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
        env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -c "SELECT client_addr, state, sync_state, replay_lag FROM pg_stat_replication;" || true
fi

echo ""
echo "=== PostgreSQL Verification Complete ==="
echo ""
echo "Summary:"
echo "  ✓ Primary pod: Running"
echo "  ✓ Read replicas: $REPLICA_READY/$REPLICA_PODS"
echo "  ✓ Database connectivity: OK"
echo "  ✓ Database '$DATABASE_NAME': Exists"
echo "  ✓ Applied migrations: $MIGRATION_COUNT"
echo "  ✓ Schema tables: $TABLE_COUNT"
echo "  ✓ Read/Write operations: OK"
echo ""
echo "PostgreSQL is ready for use!"
