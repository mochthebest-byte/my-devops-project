# Worker Helm Chart

Helm chart for the voting-app worker (.NET).

## Features

- **InitContainers**: Waits for PostgreSQL and Redis before starting
- **Multi-arch**: Supports both `linux/amd64` and `linux/arm64`

## Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `image.repository` | `<AWS_ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/my-app/worker` | ECR image (замінити на реальний Account ID) |
| `image.tag` | `latest` | Image tag (updated by CI) |
| `replicaCount` | `1` | Number of replicas |
| `postgresql.host` | `postgresql` | PostgreSQL host |
| `redis.host` | `redis-master` | Redis host |
