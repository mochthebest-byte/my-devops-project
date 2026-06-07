# Voting App — Result Service (Node.js)

Backend service that displays voting results. Built with Node.js and Express.

## Structure

```
voting-app-result/
├── Dockerfile              # Multi-arch container image
├── server.js               # Express application
├── package.json
├── views/                   # AngularJS frontend
├── charts/result/          # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml     # InitContainer for PostgreSQL
│       ├── service.yaml
│       └── _helpers.tpl
└── tests/
    ├── Dockerfile          # Test runner image (alpine + kubectl)
    ├── tests.sh            # CI test script (rollout status + retry loop)
    └── render.js           # PhantomJS render (legacy)
```

## How It Works

1. User casts a vote via the Vote service
2. Vote is published to Redis
3. Worker reads from Redis, writes to PostgreSQL
4. Result service reads from PostgreSQL and displays results

## Helm Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `image.repository` | `my-app/result` | ECR image |
| `image.tag` | `latest` | Updated by CI |
| `replicaCount` | `1` | Replicas |
| `service.port` | `81` | Service port |
| `postgresql.host` | `postgresql` | DB host |

## Tests

The `tests/tests.sh` script runs in CI:
1. Waits for deployment rollout (`kubectl rollout status`)
2. Verifies vote service is serving HTTP
3. Casts a test vote
4. Checks result page for confirmation (with retry loop)
5. Dumps pod logs on failure
