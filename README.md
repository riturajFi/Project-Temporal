# Project Temporal

Project Temporal is an AI code-change orchestration platform in progress.

The long-term goal (captured in `doc.md`) is a control plane that turns natural-language engineering tasks into validated GitHub pull requests using FastAPI, Temporal workflows, LLM calls, sandboxed validation, and observability.

Current repository status: this milestone is infrastructure-first. The API/UI/worker services are scaffolded, and a local Docker stack is implemented to run the core backend dependencies.

## Current State (What Exists Today)

Implemented now:
- Local Docker Compose stack for core platform dependencies.
- Optional observability profile (Loki, Tempo, Prometheus).
- Postgres init script creating an `app` database.
- Repo structure scaffolding for:
  - `apps/api`
  - `apps/workers`
  - `apps/ui`
  - `libs/shared`
  - `infra/helm`

Not implemented yet (in this repo state):
- FastAPI service code
- Temporal workers/workflows code
- Next.js UI code
- Kafka consumers/producers in app code

## Repo Structure

- `doc.md`: Product + architecture blueprint (target system behavior).
- `docker-compose.yml`: Local infra stack definition.
- `infra/local/postgres/init/01-init.sql`: DB bootstrap SQL.
- `infra/local/observability/`: Loki/Tempo/Prometheus configs.
- `local-dev-explained.md`: Beginner-friendly explanation of the local stack.
- `apps/*`, `libs/*`, `infra/helm/*`: scaffolds/placeholders.

## Prerequisites

- Docker Engine + Docker Compose plugin (`docker compose` command)
- Recommended: 6+ GB free RAM for full stack with observability

## How To Run

### 1) Start core infrastructure

```bash
docker compose up -d
```

This starts:
- `postgres` (localhost:5432)
- `redis` (localhost:6379)
- `zookeeper` (localhost:2181)
- `kafka` (localhost:29092)
- `temporal` (localhost:7233)
- `temporal-ui` (http://localhost:8080)

### 2) Start with observability (optional)

```bash
docker compose --profile observability up -d
```

Also starts:
- `loki` (localhost:3100)
- `tempo` (localhost:3200, OTLP gRPC on 4317)
- `prometheus` (http://localhost:9090)

### 3) Check service status

```bash
docker compose ps
```

### 4) View logs

```bash
docker compose logs -f temporal
```

Replace `temporal` with any service name (for example `kafka`, `postgres`, `prometheus`).

### 5) Stop the stack

```bash
docker compose down
```

### 6) Full reset (remove volumes/data)

```bash
docker compose down -v
```

## Quick Verification

- Temporal UI: `http://localhost:8080`
- Prometheus (if enabled): `http://localhost:9090`
- Postgres reachable on `localhost:5432`
- Redis reachable on `localhost:6379`

## Notes

- Docker named volumes persist state across restarts:
  - `postgres_data`, `redis_data`, `zookeeper_data`, `kafka_data`, `prometheus_data`
- Kafka is configured for local plaintext development only.
- This setup is for local development/bootstrap, not production.

## Source of Truth for Vision

For full intended architecture, flows, and module responsibilities, read `doc.md`.
