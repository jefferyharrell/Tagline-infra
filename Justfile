# Justfile for tagline-infra
# Unified CLI for full-stack orchestration and infra tasks.
# Usage: just <recipe>

default:
    just help

help:
    @echo "\nJustfile: Tagline Infra Project Helper\n"
    @just --list
    @echo "\nRun 'just <command>' to execute a task."
    @echo "For details: see README.md and SPEC.md."

# Docker Compose
up:
    # Start all containers in the background
    docker compose up -d

down:
    # Stop all containers
    docker compose down

build:
    # Build Docker images
    docker compose build

rebuild:
    just down
    docker compose build --no-cache
    just up
    echo "Rebuilt and started fresh containers."

logs:
    # Tail logs for all services
    docker compose logs -f

shell SERVICE="backend":
    # Open a shell in the specified container (backend, frontend, redis)
    docker exec -it tagline-infra-{{SERVICE}}-1 sh

clean:
    # Remove Docker volumes and networks, clean up artifacts
    docker compose down -v
    docker system prune -f
    echo "Cleaned up containers, volumes, and networks."

prune:
    # Remove stopped containers, unused networks, dangling images/volumes
    docker system prune -f

status:
    # Show status of all containers
    docker compose ps

# Run Alembic migrations in the backend container
migrate:
    # Apply all migrations in the backend container
    docker exec -it tagline-backend-dev alembic upgrade head

# Redis shell helper
redis-shell:
    docker exec -it tagline-redis-dev redis-cli

# Database shell helper (for SQLite)
dbshell:
    docker exec -it tagline-backend-dev sqlite3 /data/tagline.db
