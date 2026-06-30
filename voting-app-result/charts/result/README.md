# Result Helm Chart

Helm chart for the voting-app result backend (Node.js).

## Features

- **InitContainer**: Waits for PostgreSQL before starting
- **Readiness/Liveness Probes**: HTTP checks on `/`
- **Multi-arch**: Supports both `linux/amd64` and `linux/arm64`

## Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `image.repository` | `<AWS_ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/my-app/result` | ECR image (замінити на реальний Account ID) |
| `image.tag` | `latest` | Image tag (updated by CI) |
| `replicaCount` | `1` | Number of replicas |
| `service.port` | `81` | Service port |
| `postgresql.host` | `postgresql` | PostgreSQL host |
