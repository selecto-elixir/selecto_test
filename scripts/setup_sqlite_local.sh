#!/bin/bash

# Setup local SQLite database for testing without Docker

SQLITE_DB="priv/sqlite/pagila.db"
SCHEMA_FILE="priv/sqlite/schema/init.sql"
SEED_FILE="priv/sqlite/data/seed.sql"

echo "🚀 Setting up local SQLite database..."

# Remove existing database
if [ -f "$SQLITE_DB" ]; then
    echo "Removing existing database..."
    rm "$SQLITE_DB"
fi

# Create new database with schema
echo "Creating database schema..."
sqlite3 "$SQLITE_DB" < "$SCHEMA_FILE"

if [ $? -ne 0 ]; then
    echo "❌ Failed to create schema"
    exit 1
fi

# Load seed data
echo "Loading seed data..."
sqlite3 "$SQLITE_DB" < "$SEED_FILE"

if [ $? -ne 0 ]; then
    echo "❌ Failed to load seed data"
    exit 1
fi

# Verify setup
echo ""
echo "✅ SQLite database created at: $SQLITE_DB"
echo ""
echo "📊 Database Statistics:"
sqlite3 "$SQLITE_DB" <<EOF
.headers on
.mode column
SELECT 'Films' as Table, COUNT(*) as Count FROM film
UNION ALL
SELECT 'Actors', COUNT(*) FROM actor
UNION ALL  
SELECT 'Categories', COUNT(*) FROM category
UNION ALL
SELECT 'Customers', COUNT(*) FROM customer
UNION ALL
SELECT 'Rentals', COUNT(*) FROM rental;
EOF

echo ""
echo "🔧 Access database with: sqlite3 $SQLITE_DB"