#!/bin/bash

# Stop SQLite Docker environment

echo "🛑 Stopping SQLite Docker environment..."

docker-compose -f docker-compose.sqlite.yml down

echo "✅ SQLite Docker environment stopped"