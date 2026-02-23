#!/usr/bin/env bash
# ============================================================
# deploy-all.sh — Deploy the entire KubiQuest stack
# Usage: ./scripts/deploy-all.sh
# ============================================================
set -euo pipefail

REGISTRY="ghcr.io"
GITHUB_USER="${GITHUB_USER:-your-github-username}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo "======================================================"
echo "  KubiQuest — Full Stack Deployment"
echo "======================================================"

# ── 0. Verify kubectl is connected ────────────────────────
echo ""
echo "[0/7] Verifying cluster connection..."
kubectl cluster-info
kubectl get nodes

# ── 1. Namespaces ─────────────────────────────────────────
echo ""
echo "[1/7] Creating namespaces..."
kubectl apply -f k8s/namespaces/namespaces.yaml
kubectl apply -f k8s/namespaces/limitrange-app.yaml
kubectl apply -f k8s/namespaces/resourcequota-app.yaml
echo "  ✓ Namespaces ready"

# ── 2. Secrets ────────────────────────────────────────────
echo ""
echo "[2/7] Applying secrets..."
kubectl apply -f k8s/secrets/mysql-secret.yaml
kubectl apply -f k8s/secrets/rabbitmq-secret.yaml
kubectl apply -f k8s/secrets/elasticsearch-secret.yaml
kubectl apply -f k8s/secrets/api-secret.yaml
kubectl apply -f k8s/secrets/msteams-secret.yaml

# Registry secret must be created manually — check if it exists
if ! kubectl get secret registry-secret -n app &>/dev/null; then
  echo ""
  echo "  ⚠ registry-secret not found in namespace 'app'."
  echo "  Run: kubectl create secret docker-registry registry-secret \\"
  echo "    --docker-server=ghcr.io \\"
  echo "    --docker-username=${GITHUB_USER} \\"
  echo "    --docker-password=<YOUR_PAT_TOKEN> \\"
  echo "    -n app"
  echo ""
  read -p "  Press ENTER to continue after creating it, or Ctrl+C to abort..."
fi
echo "  ✓ Secrets ready"

# ── 3. RBAC ───────────────────────────────────────────────
echo ""
echo "[3/7] Applying RBAC..."
kubectl apply -f k8s/rbac/sysadmin-role.yaml
kubectl apply -f k8s/rbac/sysadmin-user.yaml
kubectl apply -f k8s/rbac/sysadmin-binding.yaml
kubectl apply -f k8s/rbac/developer-role.yaml
kubectl apply -f k8s/rbac/developer-user.yaml
kubectl apply -f k8s/rbac/developer-binding.yaml
echo "  ✓ RBAC ready"

# ── 4. Add Helm repos ─────────────────────────────────────
echo ""
echo "[4/7] Adding Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update
echo "  ✓ Helm repos ready"

# ── 5. Infrastructure (public Helm charts) ────────────────
echo ""
echo "[5/7] Deploying infrastructure..."

helm upgrade --install mysql bitnami/mysql \
  -n databases \
  -f helm-values/mysql-values.yaml \
  --wait --timeout=5m
echo "  ✓ MySQL deployed"

helm upgrade --install rabbitmq bitnami/rabbitmq \
  -n databases \
  -f helm-values/rabbitmq-values.yaml \
  --wait --timeout=5m
echo "  ✓ RabbitMQ deployed"

helm upgrade --install elasticsearch bitnami/elasticsearch \
  -n databases \
  -f helm-values/elasticsearch-values.yaml \
  --wait --timeout=10m
echo "  ✓ Elasticsearch deployed"

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  -f helm-values/ingress-nginx-values.yaml \
  --wait --timeout=3m
echo "  ✓ Ingress NGINX deployed"

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f helm-values/kube-prometheus-stack-values.yaml \
  --wait --timeout=5m
echo "  ✓ Prometheus + Grafana deployed"

helm upgrade --install loki-stack grafana/loki-stack \
  -n logging \
  -f helm-values/loki-stack-values.yaml \
  --wait --timeout=5m
echo "  ✓ Loki + Promtail deployed"

# ── 6. Microservices (custom Helm charts) ─────────────────
echo ""
echo "[6/7] Deploying microservices..."

helm upgrade --install api ./charts/api \
  -n app \
  --set image.tag="${IMAGE_TAG}" \
  --wait --timeout=5m
echo "  ✓ API deployed"

helm upgrade --install indexer ./charts/indexer \
  -n app \
  --set image.tag="${IMAGE_TAG}" \
  --wait --timeout=3m
echo "  ✓ Indexer deployed"

helm upgrade --install frontend ./charts/frontend \
  -n app \
  --set image.tag="${IMAGE_TAG}" \
  --wait --timeout=3m
echo "  ✓ Frontend deployed"

helm upgrade --install reporting ./charts/reporting \
  -n app \
  --set image.tag="${IMAGE_TAG}"
echo "  ✓ Reporting CronJob deployed"

# ── 7. Ingress ────────────────────────────────────────────
echo ""
echo "[7/7] Applying Ingress..."
kubectl apply -f k8s/ingress/ingress.yaml
echo "  ✓ Ingress applied"

# ── Final status ──────────────────────────────────────────
echo ""
echo "======================================================"
echo "  Deployment complete!"
echo "======================================================"
echo ""
echo "Get the LoadBalancer IP:"
kubectl get svc -n ingress-nginx ingress-nginx-controller
echo ""
echo "Check all pods:"
kubectl get pods -A
