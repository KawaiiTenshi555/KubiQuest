# Chapter 03 - Runbook A to Z

## Chapter A - Preconditions

Required tools:

- `kubectl`
- `helm`
- `docker`
- access to a Kubernetes cluster

Required credentials:

- GitHub user + GHCR token
- kubeconfig context with deploy rights

## Chapter B - Repository and Layout

From repository root:

- app code: `1. App/`
- kube assets: `2. Kube/`
- docs: `3. Docs/`

## Chapter C - Prepare Local Dependencies (optional)

```bash
docker compose -f "1. App/docker-compose.dev.yml" up -d
```

Use this to run local infra for development and quick checks.

## Chapter D - Build and Push Images

```bash
export GITHUB_USER=<your-github-user>
export IMAGE_TAG=latest
export GHCR_TOKEN=<your-ghcr-token>

./2.\ Kube/scripts/build-and-push.sh
```

## Chapter E - Prepare Kubernetes Secrets

Edit files in:

- `2. Kube/k8s/secrets/*.yaml`

Create registry pull secret if needed:

```bash
kubectl create secret docker-registry registry-secret \
  --docker-server=ghcr.io \
  --docker-username=<GITHUB_USER> \
  --docker-password=<GHCR_TOKEN> \
  -n app
```

## Chapter F - Full Deployment

```bash
./2.\ Kube/scripts/deploy-all.sh
```

The script applies namespaces, secrets, RBAC, infra charts, app charts, then ingress.

## Chapter G - Post Deployment Checks

```bash
kubectl get pods -A
kubectl get svc -n ingress-nginx ingress-nginx-controller
kubectl get hpa -n app
kubectl get pdb -n app
```

Smoke tests:

```bash
curl http://<EXTERNAL_IP>/
curl http://<EXTERNAL_IP>/api/health
curl http://<EXTERNAL_IP>/api/metrics
```

## Chapter H - Demo Scenarios

Autoscaling demo:

```bash
./2.\ Kube/scripts/load-test.sh http://<EXTERNAL_IP> 120
```

Zero downtime rollout demo:

```bash
./2.\ Kube/scripts/zero-downtime-demo.sh http://<EXTERNAL_IP> v2.0.0
```

Rollback demo:

```bash
./2.\ Kube/scripts/rollback-demo.sh http://<EXTERNAL_IP>
```

## Chapter I - Monitoring and Logs

Grafana:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Prometheus:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

RabbitMQ UI:

```bash
kubectl port-forward -n databases svc/rabbitmq 15672:15672
```

## Chapter J - Rollback and Recovery

Helm rollback:

```bash
helm history api -n app
helm rollback api -n app
```

Kubernetes rollout undo:

```bash
kubectl rollout history deployment/api-deployment -n app
kubectl rollout undo deployment/api-deployment -n app
```

## Chapter K - Cleanup

Delete app releases:

```bash
helm uninstall frontend api indexer reporting -n app
```

Delete infra releases:

```bash
helm uninstall mysql rabbitmq elasticsearch -n databases
helm uninstall ingress-nginx -n ingress-nginx
helm uninstall kube-prometheus-stack -n monitoring
helm uninstall loki-stack -n logging
```

Delete namespaces (optional full cleanup):

```bash
kubectl delete namespace app databases monitoring logging ingress-nginx
```
