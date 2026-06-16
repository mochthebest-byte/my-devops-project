# Local Voting-App Development — Zero AWS Dependencies

## Quickstart

```bash
# 1. Delete old clusters if any
kind delete cluster --name voting-app-local 2>/dev/null; \
kind delete cluster --name devops-local 2>/dev/null; \
kind delete cluster --name rp 2>/dev/null

# 2. Create fresh cluster
make cluster-create

# 3. Install ingress-nginx
make ingress

# 4. Deploy PostgreSQL + Redis
make dbs
make dbs-wait

# 5. Build & deploy voting-app
make build
make deploy
make deploy-ingress

# 6. Add to /etc/hosts (one time)
echo "127.0.0.1 vote.local result.local" | sudo tee -a /etc/hosts

# 7. Open browser
open http://vote.local
open http://result.local
```

Or just run all at once:
```bash
make all
# then: echo "127.0.0.1 vote.local result.local" | sudo tee -a /etc/hosts
```

## Available Make Commands

| Command | Description |
|---------|-------------|
| `make cluster-create` | Create Kind cluster (3 nodes) |
| `make cluster-delete` | Delete the cluster |
| `make cluster-status` | Show nodes and ingress |
| `make ingress` | Install ingress-nginx |
| `make ingress-status` | Check ingress pods |
| `make dbs` | Install PostgreSQL + Redis via Helm |
| `make dbs-wait` | Wait for DBs to be ready |
| `make build` | Build Docker images + load into Kind |
| `make deploy` | Helm install vote, result, worker |
| `make deploy-ingress` | Create Ingress for vote.local/result.local |
| `make all` | All of the above in sequence |
| `make clean` | Delete cluster + prune Docker networks |

## Port Conflict? (Port 80 in use)

```bash
# Check what is listening on port 80
ss -tlnp | grep :80
# or: sudo lsof -i :80

# Free port 80 — delete conflicting containers
docker ps --format "table {{.Names}}\t{{.Ports}}"
docker stop <container-name>
docker rm <container-name>

# Or use different ports in kind-config.yaml, then add to /etc/hosts:
echo "127.0.0.1 vote.local result.local" | sudo tee -a /etc/hosts
# And test via: curl -H "Host: vote.local" http://localhost:8080
```

## Disable AWS Terraform

Since AWS account is closed:

```bash
chmod +x scripts/disable-aws.sh
./scripts/disable-aws.sh
```

This renames `*.tf` → `*.tf.disabled` in `infra-aws/`.
To re-enable: `./scripts/enable-aws.sh`

## Architecture

```
Browser
  │
  │ http://vote.local / http://result.local
  ▼
/etc/hosts → 127.0.0.1
  │
  ▼
ingress-nginx (port 80 on host, mapped to port 80 in Kind)
  │
  ├── vote.local  ──▶ vote:5000 ──▶ Python/Flask ──▶ Redis + PostgreSQL
  └── result.local ──▶ result:81  ──▶ Node.js     ──▶ PostgreSQL
                         worker    ──▶ .NET        ──▶ Redis + PostgreSQL
```

## CI (GitHub Actions — No AWS)

The workflow `.github/workflows/ci-local.yml` runs on every push:
1. Creates ephemeral Kind cluster
2. Installs ingress-nginx + PostgreSQL + Redis
3. Builds Docker images
4. Deploys via Helm
5. Runs integration tests (tests.sh)
6. Dumps logs on failure
