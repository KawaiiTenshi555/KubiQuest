# KubiQuest — T-CLO-902

> Deploy a microservice e-commerce admin app in Kubernetes.

## Architecture

```
              [Browser]
                  |
        [Ingress / NGINX LB]  ← single entrypoint (LoadBalancer IP)
                  |
         [Frontend — Angular]
                  |
    ┌─────────────┴──────────────┐
    |                            |
[API — Laravel] ← ← ← ← [API — Laravel]   (replicated x2+)
    |         |         |
 [MySQL]  [RabbitMQ]  [Elasticsearch]
               |
          [Indexer — Node.JS]

[Reporting — Go CronJob]  → midnight → MySQL → MS Teams
```

## Prerequisites

- `kubectl` >= 1.28
- `helm` >= 3.12
- `docker` >= 24
- Access to a Kubernetes cluster (GKE / EKS / AKS)
- A GitHub account with a PAT token (for ghcr.io)

## Quickstart

### 1. Configure your cluster

```bash
# GKE example
gcloud container clusters get-credentials <cluster-name> --zone <zone>
kubectl cluster-info
```

### 2. Set your GitHub registry secret

```bash
kubectl create secret docker-registry registry-secret \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-pat-token> \
  -n app
```

### 3. Update secrets

Edit `k8s/secrets/*.yaml` with your actual base64-encoded passwords, then:

```bash
# Encode a value
echo -n "your-password" | base64
```

### 4. Deploy everything

```bash
./scripts/deploy-all.sh
```

Or step by step:

```bash
# Namespaces
kubectl apply -f k8s/namespaces/

# Secrets & RBAC
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/rbac/

# Helm repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Infrastructure (public charts)
helm install mysql bitnami/mysql -n databases -f helm-values/mysql-values.yaml
helm install rabbitmq bitnami/rabbitmq -n databases -f helm-values/rabbitmq-values.yaml
helm install elasticsearch bitnami/elasticsearch -n databases -f helm-values/elasticsearch-values.yaml
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx -f helm-values/ingress-nginx-values.yaml
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f helm-values/kube-prometheus-stack-values.yaml
helm install loki-stack grafana/loki-stack -n logging -f helm-values/loki-stack-values.yaml

# Microservices (custom charts)
helm install api ./charts/api -n app
helm install indexer ./charts/indexer -n app
helm install frontend ./charts/frontend -n app
helm install reporting ./charts/reporting -n app

# Ingress
kubectl apply -f k8s/ingress/ingress.yaml
```

## Access

```bash
# Get LoadBalancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller

# App
http://<EXTERNAL_IP>/

# Grafana (port-forward)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# open http://localhost:3000 — default login: admin / grafana-admin-password
```

## RBAC

Two roles are configured:

| Role      | Scope           | Permissions                                         |
|-----------|-----------------|-----------------------------------------------------|
| sysadmin  | Cluster-wide    | Full access to all resources                        |
| developer | Namespace `app` | Read pods/services, deploy, no secrets access       |

```bash
# Get sysadmin token
kubectl get secret sysadmin-user-token -n kube-system -o jsonpath='{.data.token}' | base64 -d

# Get developer token
kubectl get secret developer-user-token -n app -o jsonpath='{.data.token}' | base64 -d

# Verify developer cannot access secrets
kubectl auth can-i get secrets -n app --as=system:serviceaccount:app:developer-user
# Expected: no
```

## Demos

### Autoscaling demo

```bash
./scripts/load-test.sh http://<EXTERNAL_IP> 120
# Watch in another terminal: kubectl get hpa -n app -w
```

### Zero-downtime rolling update

```bash
./scripts/zero-downtime-demo.sh http://<EXTERNAL_IP> v2.0.0
```

### Broken deployment + rollback

```bash
./scripts/rollback-demo.sh http://<EXTERNAL_IP>
```

### Manual reporting job test

```bash
kubectl create job --from=cronjob/reporting-cronjob test-reporting -n app
kubectl logs -n app -l job-name=test-reporting
```

## Docker Images

Images are stored on ghcr.io (private registry):

```
ghcr.io/kubiquest/frontend:latest
ghcr.io/kubiquest/api:latest
ghcr.io/kubiquest/indexer:latest
ghcr.io/kubiquest/reporting:latest
```

Build and push:

```bash
docker build -t ghcr.io/kubiquest/frontend:latest -f docker/frontend/Dockerfile ./frontend
docker build -t ghcr.io/kubiquest/api:latest -f docker/api/Dockerfile ./api
docker build -t ghcr.io/kubiquest/indexer:latest -f docker/indexer/Dockerfile ./indexer
docker build -t ghcr.io/kubiquest/reporting:latest -f docker/reporting/Dockerfile ./reporting

docker push ghcr.io/kubiquest/frontend:latest
docker push ghcr.io/kubiquest/api:latest
docker push ghcr.io/kubiquest/indexer:latest
docker push ghcr.io/kubiquest/reporting:latest
```

## Project Structure

```
KubiQuest/
├── charts/            # Custom Helm charts (one per microservice)
│   ├── frontend/
│   ├── api/
│   ├── indexer/
│   └── reporting/
├── k8s/               # Raw Kubernetes manifests
│   ├── namespaces/
│   ├── rbac/
│   ├── secrets/
│   └── ingress/
├── helm-values/       # Values for public Helm charts
├── docker/            # Dockerfiles
│   ├── frontend/
│   ├── api/
│   ├── indexer/
│   └── reporting/
├── scripts/           # Demo scripts for the defense
└── bonus/             # Bonus features
```

## Author

Solo project — T-CLO-902 KubiQuest — Epitech 2026
