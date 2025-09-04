#!/bin/bash

# Start SQLite Docker environment for testing

echo "🚀 Starting SQLite Docker environment..."

# Build and start containers
docker-compose -f docker-compose.sqlite.yml up -d --build

# Wait for SQLite to be ready
echo "⏳ Waiting for SQLite to initialize..."
sleep 3

# Check if database is accessible
docker exec selecto_sqlite_cli sqlite3 /data/pagila.db "SELECT COUNT(*) FROM film;" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ SQLite database is ready!"
    
    # Show some statistics
    echo ""
    echo "📊 Database Statistics:"
    docker exec selecto_sqlite_cli sqlite3 /data/pagila.db ".headers on" ".mode column" "
        SELECT 'Films' as Table, COUNT(*) as Count FROM film
        UNION ALL
        SELECT 'Actors', COUNT(*) FROM actor
        UNION ALL  
        SELECT 'Categories', COUNT(*) FROM category
        UNION ALL
        SELECT 'Customers', COUNT(*) FROM customer
        UNION ALL
        SELECT 'Rentals', COUNT(*) FROM rental;
    "
    
    echo ""
    echo "🌐 SQLite Web Interface: http://localhost:8080"
    echo "🔧 CLI Access: docker exec -it selecto_sqlite_cli sqlite3 /data/pagila.db"
else
    echo "❌ Failed to initialize SQLite database"
    echo "Check logs with: docker-compose -f docker-compose.sqlite.yml logs"
    exit 1
fi