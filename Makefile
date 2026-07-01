# Local Kind development — no AWS required
# Usage: make <target>

# ─── Cluster ───────────────────────────────────────
.PHONY: cluster-create cluster-delete cluster-status

cluster-create:
	kind create cluster --config kind-config.yaml --name voting-app-local

cluster-delete:
	kind delete cluster --name voting-app-local

cluster-status:
	@echo "=== Nodes ==="
	kubectl get nodes -o wide
	@echo ""
	@echo "=== Ingress ==="
	kubectl get ingress -n voting-app 2>/dev/null || echo "(no ingress yet)"

# ─── Ingress ───────────────────────────────────────
.PHONY: ingress ingress-status

ingress:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	# hostNetwork + nodeSelector required because Kind's kindnet CNI
	# does not support hostPort. Without this, port 80 is unreachable.
	kubectl patch deployment -n ingress-nginx ingress-nginx-controller \
		-p '{"spec":{"template":{"spec":{"hostNetwork":true,"nodeSelector":{"kubernetes.io/hostname":"voting-app-local-control-plane"}}}}}'
	kubectl wait --namespace ingress-nginx --for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller --timeout=180s

ingress-status:
	@kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller

# ─── Databases ─────────────────────────────────────
.PHONY: dbs dbs-wait

dbs:
	helm repo add cnpg https://cloudnative-pg.github.io/charts 2>/dev/null || true
	helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
	helm repo add rabbitmq https://rabbitmq.github.io/cluster-operator/ 2>/dev/null || true
	helm repo update
	kubectl create namespace voting-app --dry-run=client -o yaml | kubectl apply -f -
	kubectl create namespace cnpg-system --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install cnpg cloudnative-pg/cloudnative-pg --namespace cnpg-system --wait
	helm upgrade --install pg-local cnpg/cluster --namespace voting-app --wait \
		--set cluster.instances=1 \
		--set 'cluster.imageName=ghcr.io/cloudnative-pg/postgresql:18' \
		--set bootstrap.initdb.database=db \
		--set bootstrap.initdb.owner=app \
		--set cluster.storage.size=1Gi
	kubectl wait --for=condition=ready cluster/pg-local -n voting-app --timeout=120s
	helm upgrade --install rabbitmq-cluster-operator rabbitmq/cluster-operator --namespace rabbitmq-system --create-namespace --wait
	helm upgrade --install rabbitmq charts/rabbitmq --namespace voting-app --wait

dbs-wait:
	kubectl wait --namespace voting-app --for=condition=ready pod -l cluster=pg-local --timeout=120s
	kubectl wait --namespace voting-app --for=condition=ready pod -l app.kubernetes.io/name=rabbitmq --timeout=120s

# ─── Build & Deploy ────────────────────────────────
.PHONY: build deploy deploy-ingress

build:
	docker build -t vote:latest voting-app-vote/
	docker build -t result:latest voting-app-result/
	docker build -t worker:latest voting-app-worker/
	kind load docker-image vote:latest result:latest worker:latest --name voting-app-local

deploy:
	helm upgrade --install vote voting-app-vote/charts/vote --namespace voting-app \
		--set image.repository=vote --set image.tag=latest --set image.pullPolicy=IfNotPresent \
		--set postgresql.host=pg-local-rw --set rabbitmq.host=rabbitmq
	helm upgrade --install result voting-app-result/charts/result --namespace voting-app \
		--set image.repository=result --set image.tag=latest --set image.pullPolicy=IfNotPresent \
		--set postgresql.host=pg-local-rw
	helm upgrade --install worker voting-app-worker/charts/worker --namespace voting-app \
		--set image.repository=worker --set image.tag=latest --set image.pullPolicy=IfNotPresent \
		--set postgresql.host=pg-local-rw --set rabbitmq.host=rabbitmq

deploy-ingress:
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

# ─── All-in-one ────────────────────────────────────
.PHONY: all

all: cluster-create ingress dbs dbs-wait build deploy deploy-ingress
	@echo ""
	@echo "============================================"
	@echo "  Local cluster ready!"
	@echo "  vote.local   -> http://vote.local"
	@echo "  result.local -> http://result.local"
	@echo "============================================"
	@echo "  Add to /etc/hosts:"
	@echo "  127.0.0.1 vote.local result.local"
	@echo ""

# ─── Tunnel ────────────────────────────────────────
.PHONY: tunnel tunnel-all tunnel-stop

tunnel:
	@echo "=== Starting Pinggy tunnel for vote ==="
	@echo "URL буде в ~/pinggy-auto.log"
	@echo "Натисни Ctrl+C для зупинки"
	@echo ""
	scripts/tunnel-pinggy.sh

tunnel-all:
	@echo "=== Starting ALL Pinggy tunnels (vote, result, grafana, keycloak) ==="
	@echo "Логи: ~/pinggy-tunnels/"
	@echo ""
	scripts/tunnel-all.sh

tunnel-stop:
	-pkill -f "a.pinggy.io" 2>/dev/null || true
	-rm -f /tmp/pinggy-tunnel.pid
	@echo "Tunnel stopped"

# ─── Cleanup ───────────────────────────────────────
.PHONY: clean

clean:
	kind delete cluster --name voting-app-local 2>/dev/null || true
	docker network prune -f 2>/dev/null || true
	@echo "Cleaned up."
