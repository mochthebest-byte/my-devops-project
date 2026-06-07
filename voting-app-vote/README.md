# Voting App — Vote Service (Python/Flask)

Frontend service for casting votes. Built with Python/Flask and Gunicorn.

## Structure

```
voting-app-vote/
├── Dockerfile              # Multi-arch container image
├── app.py                  # Flask application
├── requirements.txt
├── charts/vote/            # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml     # InitContainers + probes
│       └── service.yaml
└── k8s-local/
    ├── deployment.yaml     # Local dev manifests (kind)
    └── service.yaml
```

## Helm Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `image.repository` | `my-app/vote` | ECR image |
| `image.tag` | `latest` | Updated by CI |
| `replicaCount` | `2` | Replicas |
| `service.port` | `5000` | Service port (ClusterIP) |
| `service.targetPort` | `80` | Container port |
| `postgresql.host` | `postgresql` | DB host |
| `redis.host` | `redis-master` | Redis host |

## Features

- **InitContainers**: waits for PostgreSQL and Redis before starting
- **Readiness/Liveness Probes**: HTTP checks on `/`
- **Multi-arch**: supports amd64 + arm64
