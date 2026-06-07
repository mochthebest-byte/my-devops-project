# Keycloak — OIDC Provider

Contains the Keycloak Helm chart and ArgoCD Application for SSO/OIDC authentication.

## Structure

```
keycloak/
└── charts/keycloak/       # Helm chart
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── configmap.yaml      # Realm import (users, roles, grafana client)
        ├── service.yaml        # ClusterIP on port 8080
        ├── statefulset.yaml    # Keycloak 26.0.0 with PostgreSQL
        ├── httproute.yaml      # Expose via Gateway
        └── external-secret.yaml # DB password from AWS Secrets Manager
```

## Integration

Keycloak provides OIDC auth for Grafana:
- Realm: `myapp`
- Client: `grafana` (confidential, standard flow)
- Users: `admin` (grafana-admin), `user` (grafana-editor)

## Dependencies

- PostgreSQL (bitnami/postgresql via ArgoCD)
- ClusterSecretStore `aws-secretsmanager`
- Gateway `voting-app-gateway`
