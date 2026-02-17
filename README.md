# Project-Temporal

## Local Dev Stack (Milestone 0.2)

<!-- This command starts only the core infrastructure services in detached mode. -->
Start core services:

```bash
# Launch containers in background: postgres, redis, zookeeper, kafka, temporal, temporal-ui
# `-d` means detached mode so terminal remains free.
docker compose up -d
```

<!-- This command includes optional observability tools using compose profile selection. -->
Start core services + observability:

```bash
# Adds loki, tempo, and prometheus on top of core services.
docker compose --profile observability up -d
```

<!-- This command stops and removes all running containers from this compose file. -->
Stop everything:

```bash
# Stops containers and removes the compose network.
docker compose down
```
