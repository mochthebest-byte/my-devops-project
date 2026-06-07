# Voting App — Worker Service (.NET)

Background worker that processes votes from Redis and stores them in PostgreSQL. Built with .NET 7.

## Structure

```
voting-app-worker/
├── Dockerfile              # Multi-arch container image
├── Worker.cs               # .NET worker application
├── Worker.csproj
├── charts/worker/          # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       └── deployment.yaml     # InitContainers for PostgreSQL + Redis
```

## How It Works

1. Listens to Redis for new votes (via pub/sub or polling)
2. Reads vote data from Redis
3. Writes the vote to PostgreSQL
4. Result service reads from PostgreSQL

## Helm Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `image.repository` | `my-app/worker` | ECR image |
| `image.tag` | `latest` | Updated by CI |
| `replicaCount` | `1` | Replicas |
| `postgresql.host` | `postgresql` | DB host |
| `redis.host` | `redis-master` | Redis host |

## Features

- **InitContainers**: waits for PostgreSQL and Redis before starting
- **Multi-arch**: supports amd64 + arm64 (via BUILDPLATFORM/TARGETPLATFORM)
