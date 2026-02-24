# KubiQuest

KubiQuest is a microservices demo platform built for Kubernetes.

The repository is now organized into 3 major blocks:

- `1. App/`: application source code and Docker build files
- `2. Kube/`: Kubernetes manifests, Helm charts, values, and ops scripts
- `3. Docs/`: end-to-end documentation (Markdown + HTML), diagrams, and slide material

## Repository Layout

```text
KubiQuest/
|- 1. App/
|  |- api/
|  |- frontend/
|  |- indexer/
|  |- reporting/
|  |- docker/
|  \- docker-compose.dev.yml
|
|- 2. Kube/
|  |- k8s/
|  |- charts/
|  |- helm-values/
|  |- bonus/
|  \- scripts/
|
\- 3. Docs/
   |- MD/
   |- HTML/
   |- Diagrams/
   \- PPT/
```

## Main Documentation

Read first:

- `3. Docs/README.md`
- `3. Docs/MD/01-App.md`
- `3. Docs/MD/02-Kube.md`
- `3. Docs/MD/03-Runbook-A-to-Z.md`

HTML version:

- `3. Docs/HTML/index.html`

## Quick Start

### 1) Local infra (dev)

```bash
docker compose -f "1. App/docker-compose.dev.yml" up -d
```

### 2) Build and push images

```bash
export GITHUB_USER=<your-github-user>
export IMAGE_TAG=latest
export GHCR_TOKEN=<your-ghcr-token>

./2.\ Kube/scripts/build-and-push.sh
```

### 3) Deploy full stack on Kubernetes

```bash
./2.\ Kube/scripts/deploy-all.sh
```

### 4) Validate deployment

```bash
kubectl get pods -A
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

## Notes

- Paths include spaces (`1. App`, `2. Kube`, `3. Docs`), so commands should keep path quoting where needed.
- The deployment and demo scripts were updated to resolve paths relative to their own location.
