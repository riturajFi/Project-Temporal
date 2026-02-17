# Local Dev Explained

This file explains the local Docker stack in simple terms.

## What You Start

When you run:

```bash
docker compose up -d
```

you start these core services:

- `postgres`
- `redis`
- `zookeeper`
- `kafka`
- `temporal`
- `temporal-ui`

When you run:

```bash
docker compose --profile observability up -d
```

you also start:

- `loki`
- `tempo`
- `prometheus`

## Why Each Service Exists

- `postgres`: Main relational database. Stores durable data (jobs, metadata, etc.).
- `redis`: Fast in-memory store for cache, counters, and short-lived data.
- `zookeeper`: Coordination layer used by Kafka in this setup.
- `kafka`: Event streaming backbone for async job/timeline events.
- `temporal`: Workflow engine that runs long-lived, reliable job orchestration.
- `temporal-ui`: Browser UI for inspecting Temporal namespaces and workflows.
- `loki` (optional): Log storage/query backend.
- `tempo` (optional): Trace storage backend.
- `prometheus` (optional): Metrics scraping and storage.

## Port Map (Host -> Service)

- `5432` -> PostgreSQL
- `6379` -> Redis
- `2181` -> Zookeeper
- `29092` -> Kafka (host-facing listener)
- `7233` -> Temporal gRPC API
- `8080` -> Temporal UI
- `3100` -> Loki HTTP API (optional)
- `3200` -> Tempo HTTP API (optional)
- `4317` -> Tempo OTLP gRPC ingest (optional)
- `9090` -> Prometheus UI/API (optional)

## Who Talks to Whom

- `temporal` -> `postgres`
  - Temporal persists workflow state in Postgres.
- `kafka` -> `zookeeper`
  - Kafka uses Zookeeper for broker coordination in this local setup.
- `temporal-ui` -> `temporal`
  - UI reads workflow state from Temporal server.
- Future API/workers (when added) will talk to:
  - API -> Postgres, Redis, Kafka, Temporal
  - Workers -> Temporal, Kafka, Postgres, optional observability endpoints

## Storage and Persistence

Docker named volumes keep data across container restarts:

- `postgres_data`
- `redis_data`
- `zookeeper_data`
- `kafka_data`
- `prometheus_data`

So `docker compose down` stops/removes containers, but volume data remains.

If you need a full reset (including data), use:

```bash
docker compose down -v
```

## Basic Commands

Start core stack:

```bash
docker compose up -d
```

Start with observability:

```bash
docker compose --profile observability up -d
```

View running containers:

```bash
docker compose ps
```

View logs for one service:

```bash
docker compose logs -f temporal
```

Stop stack:

```bash
docker compose down
```

## Quick Health Checks

- Temporal UI opens: `http://localhost:8080`
- Postgres reachable on `localhost:5432`
- Redis reachable on `localhost:6379`
- Prometheus (if enabled): `http://localhost:9090`
- Loki (if enabled): `http://localhost:3100`

## Common Beginner Issues

- Port already in use:
  - Another local service is using that port.
  - Fix by stopping conflicting service or changing compose port mapping.
- Containers restart repeatedly:
  - Check logs with `docker compose logs <service>`.
- Service not available immediately:
  - Some services need startup time. Wait 10-30 seconds and retry.

