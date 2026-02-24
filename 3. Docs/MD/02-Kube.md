# Chapter 02 - Kubernetes Layer (2. Kube)

## 1. Goal

The Kubernetes layer deploys infrastructure plus all app services with:

- Helm for infra and app releases
- raw manifests for namespaces, secrets, RBAC, and ingress
- monitoring and logging stack

## 2. Folder Map

Path: `2. Kube`

- `k8s/`: namespaces, quotas, RBAC, secrets, ingress
- `charts/`: custom charts (`api`, `frontend`, `indexer`, `reporting`)
- `helm-values/`: values for public charts
- `scripts/`: deployment and demo automation
- `bonus/`: optional additions (cert-manager, kustomize, istio, cadvisor, CI)

## 3. Namespaces and Isolation

Main namespaces:

- `app`
- `databases`
- `monitoring`
- `logging`
- `ingress-nginx`

Control policies:

- `LimitRange` for per-pod resources in app namespace
- `ResourceQuota` for namespace-level limits

## 4. Secrets and Sensitive Configuration

Managed in `2. Kube/k8s/secrets`:

- MySQL credentials
- RabbitMQ credentials
- Elasticsearch credentials
- Laravel app key
- MS Teams webhook URL
- Docker registry pull secret

## 5. Helm Deployment Model

### 5.1 Public infra charts

- `bitnami/mysql`
- `bitnami/rabbitmq`
- `bitnami/elasticsearch`
- `ingress-nginx/ingress-nginx`
- `prometheus-community/kube-prometheus-stack`
- `grafana/loki-stack`

Values are in `2. Kube/helm-values`.

### 5.2 Custom app charts

- `2. Kube/charts/api`
- `2. Kube/charts/frontend`
- `2. Kube/charts/indexer`
- `2. Kube/charts/reporting`

Each chart includes:

- deployment/service config
- probes
- HPA
- PDB
- metrics/service monitor when relevant

## 6. Automation Scripts

Path: `2. Kube/scripts`

- `build-and-push.sh`
- `deploy-all.sh`
- `load-test.sh`
- `zero-downtime-demo.sh`
- `rollback-demo.sh`

Refactor applied:

- scripts now resolve paths from their own location
- they work with `1. App` and `2. Kube` directory names
- Helm and kubectl file paths are fully resolved

## 7. Ingress and Exposure

`2. Kube/k8s/ingress/ingress.yaml` is the main entry point.

Typical routes:

- `/` -> frontend
- `/api/*` -> API

## 8. Monitoring and Logs

- Prometheus scrapes app and cluster metrics
- Grafana provides dashboards
- Loki and Promtail aggregate logs

## 9. RBAC

Two main profiles:

- `sysadmin`: broad cluster access
- `developer`: app namespace access without secrets

## 10. Bonus Layer

Path: `2. Kube/bonus`

Optional extras include:

- cert-manager and TLS ingress
- kustomize staging overlay
- cAdvisor daemonset
- Istio resources
- GitHub Actions CI/CD example
