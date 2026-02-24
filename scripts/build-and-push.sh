#!/usr/bin/env bash
# ============================================================
# build-and-push.sh — Build all Docker images and push to ghcr.io
# Usage: GITHUB_USER=your-user IMAGE_TAG=latest ./scripts/build-and-push.sh
# ============================================================
set -euo pipefail

GITHUB_USER="${GITHUB_USER:-your-github-username}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="ghcr.io/${GITHUB_USER}"

echo "======================================================"
echo "  KubiQuest — Build & Push Docker Images"
echo "  Registry : ${REGISTRY}"
echo "  Tag      : ${IMAGE_TAG}"
echo "======================================================"

# Login to ghcr.io
echo ""
echo "Logging in to ghcr.io..."
echo "${GHCR_TOKEN}" | docker login ghcr.io -u "${GITHUB_USER}" --password-stdin

# Build and push each image
IMAGES=("frontend" "api" "indexer" "reporting")

for SERVICE in "${IMAGES[@]}"; do
  echo ""
  echo "──────────────────────────────────────────"
  echo "  Building ${SERVICE}..."
  echo "──────────────────────────────────────────"

  IMAGE="${REGISTRY}/${SERVICE}:${IMAGE_TAG}"

  docker build \
    -f "docker/${SERVICE}/Dockerfile" \
    -t "${IMAGE}" \
    --label "org.opencontainers.image.source=https://github.com/${GITHUB_USER}/KubiQuest" \
    --label "org.opencontainers.image.revision=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" \
    .

  docker push "${IMAGE}"
  echo "  ✓ Pushed: ${IMAGE}"
done

echo ""
echo "======================================================"
echo "  All images pushed successfully!"
echo ""
echo "  Images:"
for SERVICE in "${IMAGES[@]}"; do
  echo "    ${REGISTRY}/${SERVICE}:${IMAGE_TAG}"
done
echo "======================================================"
