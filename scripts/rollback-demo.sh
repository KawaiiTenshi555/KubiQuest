#!/usr/bin/env bash
# ============================================================
# rollback-demo.sh — Deploy a broken image and demonstrate rollback
# Usage: ./scripts/rollback-demo.sh [APP_URL]
# ============================================================
set -euo pipefail

APP_URL="${1:-}"
BROKEN_TAG="broken"
CURRENT_TAG="latest"

if [[ -z "$APP_URL" ]]; then
  APP_URL=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  APP_URL="http://${APP_URL}"
fi

echo "======================================================"
echo "  KubiQuest — Broken Deployment + Rollback Demo"
echo "======================================================"
echo "  1. Deploy broken image (readiness probe will fail)"
echo "  2. Show that existing pods keep serving traffic"
echo "  3. Rollback to previous working version"
echo "======================================================"

# ── Step 1: Show current healthy state ────────────────────
echo ""
echo "[1/4] Current healthy state:"
kubectl get pods -n app -l app.kubernetes.io/name=api
echo ""
echo "Health check (should return 200):"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "${APP_URL}/api/health" || true

# ── Step 2: Deploy broken image ───────────────────────────
echo ""
echo "[2/4] Deploying broken image (tag: '${BROKEN_TAG}')..."
echo "      This image will fail readiness probes."
echo ""
helm upgrade api ./charts/api -n app --set image.tag="${BROKEN_TAG}" &
HELM_PID=$!

echo "Watching deployment — it should STALL (not complete):"
echo "(Ctrl+C is OK here, the rollout will time out on its own)"
kubectl rollout status deployment/api-deployment -n app --timeout=90s || true

echo ""
echo "[3/4] Checking service availability during failed deployment:"
echo "      Old pods should still be serving traffic..."
for i in $(seq 1 5); do
  STATUS=$(curl -s -o /dev/null -w "HTTP %{http_code}" "${APP_URL}/api/health" --max-time 3 2>/dev/null || echo "TIMEOUT")
  echo "  Request $i: $STATUS"
  sleep 1
done

echo ""
echo "Pod status (old pods running, new pods stuck in Pending/Init):"
kubectl get pods -n app -l app.kubernetes.io/name=api

# Kill the stalled helm process if still running
kill $HELM_PID 2>/dev/null || true

# ── Step 3: Rollback ──────────────────────────────────────
echo ""
echo "[4/4] Rolling back to previous version..."
echo "      Command: helm rollback api -n app"
helm rollback api -n app

echo ""
echo "Waiting for rollback to complete..."
kubectl rollout status deployment/api-deployment -n app --timeout=3m

echo ""
echo "======================================================"
echo "  Rollback complete!"
echo ""
echo "Final pod state:"
kubectl get pods -n app -l app.kubernetes.io/name=api
echo ""
echo "Service health after rollback:"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "${APP_URL}/api/health" || true
echo ""
echo "Helm release history:"
helm history api -n app
echo "======================================================"
