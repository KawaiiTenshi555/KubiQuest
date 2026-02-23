#!/usr/bin/env bash
# ============================================================
# load-test.sh — Generate traffic to trigger HPA autoscaling
# Usage: ./scripts/load-test.sh [APP_URL] [DURATION_SECONDS]
# Example: ./scripts/load-test.sh http://34.120.10.1 120
# ============================================================
set -euo pipefail

APP_URL="${1:-}"
DURATION="${2:-120}"
CONCURRENCY=20

if [[ -z "$APP_URL" ]]; then
  echo "Getting LoadBalancer IP..."
  APP_URL=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  APP_URL="http://${APP_URL}"
fi

echo "======================================================"
echo "  KubiQuest — Load Test (Autoscaling Demo)"
echo "======================================================"
echo "  Target:      ${APP_URL}"
echo "  Duration:    ${DURATION}s"
echo "  Concurrency: ${CONCURRENCY} parallel requests"
echo ""
echo "  Watch HPA in another terminal:"
echo "  kubectl get hpa -n app -w"
echo ""
echo "  Watch pods scaling in another terminal:"
echo "  kubectl get pods -n app -w"
echo "======================================================"
echo ""

# Show current state before load
echo "Current replicas before load:"
kubectl get deployments -n app
echo ""

START=$(date +%s)
COUNT=0
ERRORS=0

echo "Starting load... (Ctrl+C to stop)"
while true; do
  NOW=$(date +%s)
  ELAPSED=$(( NOW - START ))

  if (( ELAPSED >= DURATION )); then
    break
  fi

  # Send concurrent requests
  for i in $(seq 1 $CONCURRENCY); do
    (
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${APP_URL}/api/health" --max-time 5 2>/dev/null || echo "000")
      if [[ "$STATUS" != "200" ]]; then
        echo -n "E"
      else
        echo -n "."
      fi
    ) &
  done
  wait
  COUNT=$(( COUNT + CONCURRENCY ))

  printf "\n  [%ds/%ds] Requests sent: %d" "$ELAPSED" "$DURATION" "$COUNT"
done

echo ""
echo ""
echo "======================================================"
echo "  Load test complete — ${COUNT} requests sent"
echo ""
echo "Final replica count:"
kubectl get deployments -n app
echo ""
echo "HPA status:"
kubectl get hpa -n app
echo "======================================================"
