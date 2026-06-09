# Local Development with Kind + Ingress-Nginx

## Prerequisites

- Docker Desktop / Rancher Desktop (running)
- `kind` CLI (`brew install kind` or `go install sigs.k8s.io/kind@latest`)
- `kubectl`
- `helm`

## Port Conflicts

The Kind config maps ports 80/443 to the host. If those ports are in use:

```bash
# Check what's using port 80
sudo lsof -i :80

# Delete old Kind clusters if they have port 80 bound
kind delete cluster --name devops-local
kind delete cluster --name kind
kind delete cluster --name rp

# Or use existing cluster and skip 'kind create cluster'
kind get clusters
kind export kubeconfig --name <existing-cluster>
```

## Step 1: Create Kind Cluster

```bash
# From the project root
kind create cluster --config kind-config.yaml --name voting-app-local
```

This creates:
- 1 control-plane node (with `ingress-ready=true` label, ports 80+443 mapped)
- 2 worker nodes

Verify:
```bash
kubectl cluster-info --context kind-voting-app-local
kubectl get nodes
```

## Step 2: Install Ingress-Nginx

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for it to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

Why ingress-nginx for Kind instead of AWS Gateway API:
- Kind does not support AWS ALB (no cloud)
- ingress-nginx is the standard for local dev
- Works with `*.local` / `*.nip.io` domains without LoadBalancer
- The Ingress YAML is simple and portable

## Step 3: Add Local Domains to /etc/hosts

```bash
# Linux/macOS
echo "127.0.0.1 vote.local result.local grafana.local keycloak.local" | sudo tee -a /etc/hosts

# Windows (PowerShell as Admin):
# Add-Content C:\Windows\System32\drivers\etc\hosts "`n127.0.0.1 vote.local result.local grafana.local keycloak.local"
```

Now `http://vote.local` points to your local Kind cluster's Ingress.

## Step 4: Install Dependencies (PostgreSQL, Redis)

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

kubectl create namespace voting-app

# PostgreSQL
helm upgrade --install postgresql bitnami/postgresql \
  --namespace voting-app --version 16.x --set auth.database=db \
  --set auth.username=vote_user --set auth.password=testpass

# Redis
helm upgrade --install redis bitnami/redis \
  --namespace voting-app --version 21.x --set auth.enabled=false

# Wait for both
kubectl wait --namespace voting-app --for=condition=ready pod \
  -l app.kubernetes.io/instance=postgresql --timeout=120s
kubectl wait --namespace voting-app --for=condition=ready pod \
  -l app.kubernetes.io/instance=redis --timeout=120s
```

## Step 5: Build & Deploy Services

```bash
# Build images
docker build -t vote:latest voting-app-vote/
docker build -t result:latest voting-app-result/
docker build -t worker:latest voting-app-worker/

# Load into Kind
kind load docker-image vote:latest result:latest worker:latest --name voting-app-local

# Deploy via Helm
helm upgrade --install vote voting-app-vote/charts/vote --namespace voting-app \
  --set image.repository=vote --set image.tag=latest \
  --set image.pullPolicy=IfNotPresent
helm upgrade --install result voting-app-result/charts/result --namespace voting-app \
  --set image.repository=result --set image.tag=latest \
  --set image.pullPolicy=IfNotPresent
helm upgrade --install worker voting-app-worker/charts/worker --namespace voting-app \
  --set image.repository=worker --set image.tag=latest \
  --set image.pullPolicy=IfNotPresent
```

## Step 6: Create Ingress

```bash
kubectl apply -f - << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: voting-app-ingress
  namespace: voting-app
spec:
  ingressClassName: nginx
  rules:
    - host: vote.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: vote
                port:
                  number: 5000
    - host: result.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: result
                port:
                  number: 81
EOF
```

## Step 7: Test

```bash
# These should now work from your browser:
curl -H "Host: vote.local" http://localhost
curl -H "Host: result.local" http://localhost

# Or directly via /etc/hosts:
curl http://vote.local
curl http://result.local
```

## Adapting Helm Charts for Local vs Production

### Pattern: `values-{env}.yaml`

The same charts support both Kind and AWS by using environment-specific values files:

```bash
# Local dev (Kind + Ingress)
helm upgrade --install vote ./charts/vote \
  --namespace voting-app \
  -f k8s/local/values-local.yaml

# Production (EKS + Gateway API)
helm upgrade --install vote ./charts/vote \
  --namespace voting-app \
  -f k8s/values-production.yaml
```

### Key Differences

| Aspect | Local (Kind) | Production (EKS) |
|--------|-------------|-------------------|
| **Ingress** | ingress-nginx | Gateway API (ALB) |
| **Service type** | NodePort | ClusterIP |
| **Secrets** | Plain (no ESO) | External Secrets |
| **TLS** | None (HTTP only) | cert-manager + ACM |
| **DNS** | `/etc/hosts` | Route53 |
| **PostgreSQL** | bitnami chart with localpass | AWS Secrets Manager |
| **Build** | `docker build` + `kind load` | ECR + GitHub Actions |

## CI: Ephemeral Kind Cluster in GitHub Actions

The workflow `.github/workflows/ci-kind-test.yml` does this automatically:

1. Create Kind cluster with 3 nodes
2. Install ingress-nginx
3. Install PostgreSQL, Redis
4. Build Docker images, load into Kind
5. Deploy all 3 services via Helm
6. Create Ingress rules
7. Run integration tests
8. Dump logs on failure (auto-diagnostics)

Trigger with any push:

```bash
git push origin <branch>
```

Watch at: `https://github.com/mochthebest-byte/my-devops-project/actions`
