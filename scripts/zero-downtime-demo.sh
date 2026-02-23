#!/usr/bin/env bash
# ============================================================
# zero-downtime-demo.sh — Demonstrate rolling update with zero downtime
# Usage: ./scripts/zero-downtime-demo.sh [APP_URL] [NEW_IMAGE_TAG]
# Example: ./scripts/zero-downtime-demo.sh http://34.120.10.1 v2.0.0
# ============================================================
set -euo pipefail

APP_URL="${1:-}"
NEW_TAG="${2:-v2.0.0}"

if [[ -z "$APP_URL" ]]; then
  APP_URL=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  APP_URL="http://${APP_URL}"
fi

echo "======================================================"
echo "  KubiQuest — Zero-Downtime Rolling Update Demo"
echo "======================================================"
echo "  Target:    ${APP_URL}"
echo "  New tag:   ${NEW_TAG}"
echo ""
echo "  The API will be updated to '${NEW_TAG}' while"
echo "  we keep sending requests — zero failures expected."
echo "======================================================"
echo ""

# Show current state
echo "Current API pods:"
kubectl get pods -n app -l app.kubernetes.io/name=api
echo ""

# Start background traffic loop
TOTAL=0
ERRORS=0
TMPFILE=$(mktemp)

echo "Starting continuous traffic (background)..."
(
  while true; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${APP_URL}/api/health" --max-time 3 2>/dev/null || echo "000")
    if [[ "$STATUS" == "200" ]]; then
      echo "OK" >> "$TMPFILE"
    else
      echo "ERR:${STATUS}" >> "$TMPFILE"
    fi
    sleep 0.2
  done
) &
TRAFFIC_PID=$!

sleep 2
echo "Traffic is running (PID: ${TRAFFIC_PID})..."
echo ""

# Trigger the rolling update
echo "Triggering rolling update: helm upgrade api with tag '${NEW_TAG}'..."
helm upgrade api ./charts/api -n app --set image.tag="${NEW_TAG}" &
HELM_PID=$!

echo ""
echo "Watching pods roll..."
kubectl rollout status deployment/api-deployment -n app --timeout=5m

# Wait for helm to finish
wait $HELM_PID

sleep 3

# Stop traffic
kill $TRAFFIC_PID 2>/dev/null || true
wait $TRAFFIC_PID 2>/dev/null || true

# Count results
OK_COUNT=$(grep -c "^OK$" "$TMPFILE" 2>/dev/null || echo 0)
ERR_COUNT=$(grep -c "^ERR" "$TMPFILE" 2>/dev/null || echo 0)
rm -f "$TMPFILE"

echo ""
echo "======================================================"
echo "  Rolling update complete!"
echo ""
echo "  Successful requests : ${OK_COUNT}"
echo "  Failed requests     : ${ERR_COUNT}"
echo ""
if [[ "$ERR_COUNT" -eq 0 ]]; then
  echo "  RESULT: ✓ ZERO DOWNTIME — No failures during rolling update!"
else
  echo "  RESULT: ✗ ${ERR_COUNT} failures detected during rolling update."
fi
echo ""
echo "  New pods:"
kubectl get pods -n app -l app.kubernetes.io/name=api
echo "======================================================"
