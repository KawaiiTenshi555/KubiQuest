#!/usr/bin/env bash
# ============================================================
# deploy-all.sh - Deploy the entire KubiQuest stack
# Usage: ./2.\ Kube/scripts/deploy-all.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
K8S_DIR="${KUBE_DIR}/k8s"
HELM_VALUES_DIR="${KUBE_DIR}/helm-values"
CHARTS_DIR="${KUBE_DIR}/charts"

GITHUB_USER="${GITHUB_USER:-your-github-username}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo "======================================================"
echo "  KubiQuest - Full Stack Deployment"
echo "======================================================"

echo ""
echo "[0/7] Verifying cluster connection..."
kubectl cluster-info
kubectl get nodes

echo ""
echo "[1/7] Creating namespaces..."
kubectl apply -f "${K8S_DIR}/namespaces/namespaces.yaml"
kubectl apply -f "${K8S_DIR}/namespaces/limitrange-app.yaml"
kubectl apply -f "${K8S_DIR}/namespaces/resourcequota-app.yaml"
echo "Namespaces ready"

echo ""
echo "[2/7] Applying secrets..."
kubectl apply -f "${K8S_DIR}/secrets/mysql-secret.yaml"
kubectl apply -f "${K8S_DIR}/secrets/rabbitmq-secret.yaml"
kubectl apply -f "${K8S_DIR}/secrets/elasticsearch-secret.yaml"
kubectl apply -f "${K8S_DIR}/secrets/api-secret.yaml"
kubectl apply -f "${K8S_DIR}/secrets/msteams-secret.yaml"

if ! kubectl get secret registry-secret -n app &>/dev/null; then
  echo ""
  echo "WARNING: registry-secret not found in namespace app."
  echo "Run:"
  echo "kubectl create secret docker-registry registry-secret \\"
  echo "  --docker-server=ghcr.io \\"
  echo "  --docker-username=${GITHUB_USER} \\"
  echo "  --docker-password=<YOUR_PAT_TOKEN> \\"
  echo "  -n app"
  echo ""
  read -r -p "Press ENTER to continue after creating it, or Ctrl+C to abort..."
fi
echo "Secrets ready"

echo ""
echo "[3/7] Applying RBAC..."
kubectl apply -f "${K8S_DIR}/rbac/sysadmin-role.yaml"
kubectl apply -f "${K8S_DIR}/rbac/sysadmin-user.yaml"
kubectl apply -f "${K8S_DIR}/rbac/sysadmin-binding.yaml"
kubectl apply -f "${K8S_DIR}/rbac/developer-role.yaml"
kubectl apply -f "${K8S_DIR}/rbac/developer-user.yaml"
kubectl apply -f "${K8S_DIR}/rbac/developer-binding.yaml"
echo "RBAC ready"

echo ""
echo "[4/7] Adding Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update
echo "Helm repos ready"

echo ""
echo "[5/7] Deploying infrastructure..."

helm upgrade --install mysql bitnami/mysql \
  -n databases \
  -f "${HELM_VALUES_DIR}/mysql-values.yaml" \
  --wait --timeout=5m
echo "MySQL deployed"

helm upgrade --install rabbitmq bitnami/rabbitmq \
  -n databases \
  -f "${HELM_VALUES_DIR}/rabbitmq-values.yaml" \
  --wait --timeout=5m
echo "RabbitMQ deployed"

helm upgrade --install elasticsearch bitnami/elasticsearch \
  -n databases \
  -f "${HELM_VALUES_DIR}/elasticsearch-values.yaml" \
  --wait --timeout=10m
echo "Elasticsearch deployed"

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  -f "${HELM_VALUES_DIR}/ingress-nginx-values.yaml" \
  --wait --timeout=3m
echo "Ingress NGINX deployed"

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f "${HELM_VALUES_DIR}/kube-prometheus-stack-values.yaml" \
  --wait --timeout=5m
echo "Prometheus + Grafana deployed"

helm upgrade --install loki-stack grafana/loki-stack \
  -n logging \
  -f "${HELM_VALUES_DIR}/loki-stack-values.yaml" \
  --wait --timeout=5m
echo "Loki + Promtail deployed"

echo ""
echo "[6/7] Deploying microservices..."

helm upgrade --install api "${CHARTS_DIR}/api" \
  -n app \
  --set image.tag="${IMAGE_TAG}" \
  --wait --timeout=5m
echo "API deployed"

helm upgrade --install indexer "${CHARTS_DIR}/indexer" \
  -n app \
  --set image.tag="${IMAGE_TAG}" \
  --wait --timeout=3m
echo "Indexer deployed"

helm upgrade --install frontend "${CHARTS_DIR}/frontend" \
  -n app \
  --set image.tag="${IMAGE_TAG}" \
  --wait --timeout=3m
echo "Frontend deployed"

helm upgrade --install reporting "${CHARTS_DIR}/reporting" \
  -n app \
  --set image.tag="${IMAGE_TAG}"
echo "Reporting CronJob deployed"

echo ""
echo "[7/7] Applying Ingress..."
kubectl apply -f "${K8S_DIR}/ingress/ingress.yaml"
echo "Ingress applied"

echo ""
echo "======================================================"
echo "Deployment complete"
echo "======================================================"
echo ""
echo "Get the LoadBalancer IP:"
kubectl get svc -n ingress-nginx ingress-nginx-controller
echo ""
echo "Check all pods:"
kubectl get pods -A
