#!/bin/bash
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

NAMESPACE=${NAMESPACE:-"postgres"}
DATABASE_NAME=${DATABASE_NAME:-"learning_platform"}
MIGRATIONS_DIR="$SKILL_DIR/migrations"

# Get PostgreSQL password from secret
POSTGRES_PASSWORD=$(kubectl get secret -n "$NAMESPACE" postgres-postgresql -o jsonpath='{.data.postgres-password}' 2>/dev/null | base64 -d)
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "Error: Could not retrieve PostgreSQL password from secret"
    exit 1
fi

echo "=== Running PostgreSQL Migrations ==="
echo ""

# Disable synchronous commit to avoid hanging on replica issues
echo "1. Checking replication settings..."
SYNC_COMMIT=$(kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
    env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -t -c "SHOW synchronous_commit;" 2>/dev/null | tr -d ' ')

if [ "$SYNC_COMMIT" != "off" ]; then
    echo "   Disabling synchronous_commit to prevent migration hangs..."
    kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
        env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -c "ALTER SYSTEM SET synchronous_commit = 'off';" > /dev/null
    kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
        env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -c "SELECT pg_reload_conf();" > /dev/null
    echo "   ✓ Synchronous commit disabled"
else
    echo "   ✓ Synchronous commit already disabled"
fi
echo ""

# Check if migrations directory exists
if [ ! -d "$MIGRATIONS_DIR" ]; then
    echo "Error: Migrations directory not found: $MIGRATIONS_DIR"
    exit 1
fi

# Get list of migration files
MIGRATION_FILES=$(find "$MIGRATIONS_DIR" -name "*.sql" | sort)

if [ -z "$MIGRATION_FILES" ]; then
    echo "No migration files found in $MIGRATIONS_DIR"
    exit 0
fi

echo "2. Found migration files:"
echo "$MIGRATION_FILES" | sed 's/^/   - /'
echo ""

# Create migrations tracking table
echo "3. Creating migrations tracking table..."
kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
    env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d "$DATABASE_NAME" -c \
    "CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(255) PRIMARY KEY, applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);" > /dev/null
echo "   ✓ Migrations table ready"

# Apply each migration
echo ""
echo "4. Applying migrations..."
for migration_file in $MIGRATION_FILES; do
    migration_name=$(basename "$migration_file" .sql)

    # Check if migration already applied
    APPLIED=$(kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
        env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d "$DATABASE_NAME" -t -c \
        "SELECT COUNT(*) FROM schema_migrations WHERE version='$migration_name';" 2>/dev/null | tr -d ' ')

    if [ "$APPLIED" = "1" ]; then
        echo "   ⊘ Skipping $migration_name (already applied)"
    else
        echo "   → Applying $migration_name..."

        # Apply migration
        cat "$migration_file" | kubectl exec -i -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
            env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d "$DATABASE_NAME"

        # Record migration
        kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
            env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d "$DATABASE_NAME" -c \
            "INSERT INTO schema_migrations (version) VALUES ('$migration_name');"

        echo "   ✓ Applied $migration_name"
    fi
done

echo ""
echo "5. Listing applied migrations..."
kubectl exec -n "$NAMESPACE" postgres-postgresql-primary-0 -- \
    env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d "$DATABASE_NAME" -c \
    "SELECT version, applied_at FROM schema_migrations ORDER BY applied_at;"

echo ""
echo "=== Migrations Complete ==="
