#!/bin/bash
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

NAMESPACE=${NAMESPACE:-"postgres"}
DATABASE_NAME=${DATABASE_NAME:-"learning_platform"}
MIGRATIONS_DIR="$SKILL_DIR/migrations"

echo "=== Running PostgreSQL Migrations ==="
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

echo "1. Found migration files:"
echo "$MIGRATION_FILES" | sed 's/^/   - /'
echo ""

# Create migrations tracking table
echo "2. Creating migrations tracking table..."
kubectl exec -n "$NAMESPACE" postgres-postgresql-0 -- psql -U postgres -d "$DATABASE_NAME" <<EOF
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(255) PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
echo "   ✓ Migrations table ready"

# Apply each migration
echo ""
echo "3. Applying migrations..."
for migration_file in $MIGRATION_FILES; do
    migration_name=$(basename "$migration_file" .sql)

    # Check if migration already applied
    APPLIED=$(kubectl exec -n "$NAMESPACE" postgres-postgresql-0 -- \
        psql -U postgres -d "$DATABASE_NAME" -t -c \
        "SELECT COUNT(*) FROM schema_migrations WHERE version='$migration_name';" 2>/dev/null | tr -d ' ')

    if [ "$APPLIED" = "1" ]; then
        echo "   ⊘ Skipping $migration_name (already applied)"
    else
        echo "   → Applying $migration_name..."

        # Apply migration
        cat "$migration_file" | kubectl exec -i -n "$NAMESPACE" postgres-postgresql-0 -- \
            psql -U postgres -d "$DATABASE_NAME"

        # Record migration
        kubectl exec -n "$NAMESPACE" postgres-postgresql-0 -- \
            psql -U postgres -d "$DATABASE_NAME" -c \
            "INSERT INTO schema_migrations (version) VALUES ('$migration_name');"

        echo "   ✓ Applied $migration_name"
    fi
done

echo ""
echo "4. Listing applied migrations..."
kubectl exec -n "$NAMESPACE" postgres-postgresql-0 -- \
    psql -U postgres -d "$DATABASE_NAME" -c \
    "SELECT version, applied_at FROM schema_migrations ORDER BY applied_at;"

echo ""
echo "=== Migrations Complete ==="
