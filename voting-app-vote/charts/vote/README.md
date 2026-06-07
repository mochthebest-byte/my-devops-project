# Vote Helm Chart

Helm chart for the voting-app vote frontend (Python/Flask).

## Features

- **InitContainers**: Waits for PostgreSQL and Redis before starting
- **Readiness/Liveness Probes**: HTTP checks on `/`
- **Multi-arch**: Supports both `linux/amd64` and `linux/arm64`
- **Secrets**: PostgreSQL password from `existingSecret`

## Dependencies

- PostgreSQL (via ExternalSecret)
- Redis

## Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `image.repository` | `428156589409.dkr.ecr.us-east-1.amazonaws.com/my-app/vote` | ECR image |
| `image.tag` | `latest` | Image tag (updated by CI) |
| `replicaCount` | `2` | Number of replicas |
| `service.port` | `5000` | Service port |
| `service.targetPort` | `80` | Container port |
| `postgresql.host` | `postgresql` | PostgreSQL host |
| `redis.host` | `redis-master` | Redis host |

## How CI Updates This

1. CI builds a new Docker image → pushes to ECR
2. CI updates the `image.tag` in the GitOps repo's `values.yaml`
3. ArgoCD syncs the change to the cluster
