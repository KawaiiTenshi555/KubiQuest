#!/usr/bin/env bash
# ============================================================
# build-and-push.sh - Build all Docker images and push to ghcr.io
# Usage: GITHUB_USER=your-user IMAGE_TAG=latest ./2.\ Kube/scripts/build-and-push.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${KUBE_DIR}/.." && pwd)"
DOCKER_DIR="${ROOT_DIR}/1. App/docker"

GITHUB_USER="${GITHUB_USER:-your-github-username}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="ghcr.io/${GITHUB_USER}"

if [[ -z "${GHCR_TOKEN:-}" ]]; then
  echo "ERROR: GHCR_TOKEN is not set."
  echo "Export GHCR_TOKEN before running this script."
  exit 1
fi

echo "======================================================"
echo "  KubiQuest - Build and Push Docker Images"
echo "  Registry : ${REGISTRY}"
echo "  Tag      : ${IMAGE_TAG}"
echo "======================================================"

echo ""
echo "Logging in to ghcr.io..."
echo "${GHCR_TOKEN}" | docker login ghcr.io -u "${GITHUB_USER}" --password-stdin

IMAGES=("frontend" "api" "indexer" "reporting")

for SERVICE in "${IMAGES[@]}"; do
  echo ""
  echo "----------------------------------------"
  echo "Building ${SERVICE}..."
  echo "----------------------------------------"

  IMAGE="${REGISTRY}/${SERVICE}:${IMAGE_TAG}"
  DOCKERFILE="${DOCKER_DIR}/${SERVICE}/Dockerfile"

  docker build \
    -f "${DOCKERFILE}" \
    -t "${IMAGE}" \
    --label "org.opencontainers.image.source=https://github.com/${GITHUB_USER}/KubiQuest" \
    --label "org.opencontainers.image.revision=$(git -C "${ROOT_DIR}" rev-parse --short HEAD 2>/dev/null || echo 'unknown')" \
    "${ROOT_DIR}"

  docker push "${IMAGE}"
  echo "Pushed: ${IMAGE}"
done

echo ""
echo "======================================================"
echo "All images pushed successfully."
echo "Images:"
for SERVICE in "${IMAGES[@]}"; do
  echo "  ${REGISTRY}/${SERVICE}:${IMAGE_TAG}"
done
echo "======================================================"
