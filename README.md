# KubiQuest — T-CLO-902

> Epitech — Module Cloud (T10) — Déploiement d'une application e-commerce microservices dans Kubernetes

---

## Table des matières

1. [Architecture](#architecture)
2. [Microservices](#microservices)
3. [Infrastructure](#infrastructure)
4. [Prérequis](#prérequis)
5. [Build & Push des images Docker](#build--push-des-images-docker)
6. [Provisionnement du cluster](#provisionnement-du-cluster)
7. [Configuration des secrets](#configuration-des-secrets)
8. [Déploiement complet](#déploiement-complet)
9. [Accès aux services](#accès-aux-services)
10. [RBAC — Rôles et utilisateurs](#rbac--rôles-et-utilisateurs)
11. [Scripts de démonstration](#scripts-de-démonstration)
12. [Rollback](#rollback)
13. [Monitoring & Logs](#monitoring--logs)
14. [Bonus](#bonus)
15. [Structure du projet](#structure-du-projet)
16. [Auteur](#auteur)

---

## Architecture

```
                        [Browser]
                            |
               [Ingress NGINX — LoadBalancer IP]    ← point d'entrée unique
                            |
                   [Frontend — Angular]
                            |
              ┌─────────────┴─────────────┐
              |                           |
       [API — Laravel]             [API — Laravel]   ← répliqué (min 2 pods)
        |       |       |
     [MySQL] [RabbitMQ] [Elasticsearch]
                 |
          [Indexer — Node.JS]          ← consommateur RabbitMQ → ES

[Reporting — Go CronJob] → minuit → MySQL → MS Teams webhook

[Prometheus + Grafana]  ← monitoring cluster + apps
[Loki + Promtail]       ← log aggregation
```

### Flux de données

| # | Flux |
|---|------|
| 1 | Browser → Ingress → Frontend (SPA Angular) |
| 2 | Frontend → `GET/POST/DELETE /api/products` → API Laravel → MySQL |
| 3 | API → fanout exchange `products` → RabbitMQ |
| 4 | Indexer consomme queue `products-indexer` → Elasticsearch |
| 5 | Frontend → `GET /api/search?q=…` → API → Elasticsearch |
| 6 | CronJob Go (00:00 UTC) → MySQL COUNT → HTTP POST MS Teams |

---

## Microservices

| Service | Technologie | Type K8s | Replicas | Port |
|---------|-------------|----------|----------|------|
| frontend | Angular 17 + nginx | Deployment | 2–5 (HPA) | 80 |
| api | Laravel 11 / PHP 8.2 | Deployment | 2–6 (HPA) | 80 |
| indexer | Node.JS 20 | Deployment | 1–3 (HPA) | 3000 |
| reporting | Go 1.22 | CronJob | — (00:00 UTC) | — |

---

## Infrastructure

| Composant | Chart Helm | Namespace |
|-----------|-----------|-----------|
| MySQL 8.0 | `bitnami/mysql` | `databases` |
| RabbitMQ 3 | `bitnami/rabbitmq` | `databases` |
| Elasticsearch 8 | `bitnami/elasticsearch` | `databases` |
| Ingress NGINX | `ingress-nginx/ingress-nginx` | `ingress-nginx` |
| Prometheus + Grafana | `prometheus-community/kube-prometheus-stack` | `monitoring` |
| Loki + Promtail | `grafana/loki-stack` | `logging` |

---

## Prérequis

| Outil | Version minimale |
|-------|-----------------|
| `kubectl` | >= 1.28 |
| `helm` | >= 3.12 |
| `docker` | >= 24 |
| `git` | >= 2.40 |
| Compte GitHub | PAT avec `write:packages` |
| Cluster K8s | GKE / EKS / AKS (≥ 3 noeuds `e2-standard-2`) |

---

## Build & Push des images Docker

Les images sont hébergées sur **GitHub Container Registry** (`ghcr.io`).

```bash
# 1. Exporter les variables
export GITHUB_USER=<ton-username-github>
export IMAGE_TAG=latest

# 2. Créer un PAT GitHub (scopes: read:packages, write:packages)
export GHCR_TOKEN=<ton-pat-token>

# 3. Build & push des 4 images en une commande
./scripts/build-and-push.sh
```

Le script construit les images depuis la **racine du repo** (build context monorepo) :

```
ghcr.io/<GITHUB_USER>/frontend:latest
ghcr.io/<GITHUB_USER>/api:latest
ghcr.io/<GITHUB_USER>/indexer:latest
ghcr.io/<GITHUB_USER>/reporting:latest
```

> Rendre le registre **public** sur GitHub (Packages → Change visibility) ou configurer `registry-secret` dans chaque namespace.

---

## Provisionnement du cluster

### GKE (recommandé)

```bash
# Créer le cluster (3 noeuds minimum pour la tolérance aux pannes)
gcloud container clusters create kubiquest \
  --num-nodes=3 \
  --machine-type=e2-standard-2 \
  --enable-autoscaling --min-nodes=3 --max-nodes=6 \
  --zone=europe-west1-b

# Configurer kubectl
gcloud container clusters get-credentials kubiquest --zone=europe-west1-b

# Vérifier
kubectl cluster-info
kubectl get nodes
```

### EKS / AKS

Adapter la commande de création du cluster selon le cloud provider, puis configurer `kubectl` avec le kubeconfig fourni.

---

## Configuration des secrets

> **Ne jamais commiter de valeurs réelles dans Git.** Les fichiers YAML contiennent des placeholders en base64.

### Encoder une valeur

```bash
echo -n "mon-mot-de-passe" | base64
```

### Secrets à configurer

Éditer chaque fichier dans `k8s/secrets/` :

| Fichier | Clés à renseigner |
|---------|-------------------|
| `mysql-secret.yaml` | `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER` |
| `rabbitmq-secret.yaml` | `RABBITMQ_DEFAULT_USER`, `RABBITMQ_DEFAULT_PASS`, `RABBITMQ_ERLANG_COOKIE` |
| `elasticsearch-secret.yaml` | `ELASTICSEARCH_PASSWORD`, `ELASTICSEARCH_USER` |
| `msteams-secret.yaml` | `MSTEAMS_WEBHOOK_URL` |
| `api-secret.yaml` | `APP_KEY` (généré avec `php artisan key:generate --show`) |
| `registry-secret.yaml` | Credentials ghcr.io (voir ci-dessous) |

### Secret registre Docker

```bash
kubectl create secret docker-registry registry-secret \
  --docker-server=ghcr.io \
  --docker-username=<GITHUB_USER> \
  --docker-password=<GHCR_TOKEN> \
  --namespace=app
```

---

## Déploiement complet

### Option A — Script tout-en-un

```bash
./scripts/deploy-all.sh
```

Le script déploie dans l'ordre :
1. Namespaces
2. Secrets & RBAC
3. Repos Helm
4. Infrastructure (MySQL, RabbitMQ, Elasticsearch, Ingress NGINX, Prometheus, Loki)
5. Microservices (frontend, api, indexer, reporting)
6. Ingress

### Option B — Étape par étape

```bash
# 1. Namespaces
kubectl apply -f k8s/namespaces/

# 2. Secrets
kubectl apply -f k8s/secrets/

# 3. RBAC
kubectl apply -f k8s/rbac/

# 4. Repos Helm
helm repo add bitnami              https://charts.bitnami.com/bitnami
helm repo add ingress-nginx        https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana              https://grafana.github.io/helm-charts
helm repo update

# 5. Infrastructure (attendre que chaque déploiement soit Ready avant le suivant)
helm install mysql         bitnami/mysql             -n databases    -f helm-values/mysql-values.yaml
helm install rabbitmq      bitnami/rabbitmq          -n databases    -f helm-values/rabbitmq-values.yaml
helm install elasticsearch bitnami/elasticsearch     -n databases    -f helm-values/elasticsearch-values.yaml
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx -f helm-values/ingress-nginx-values.yaml
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring -f helm-values/kube-prometheus-stack-values.yaml
helm install loki-stack    grafana/loki-stack        -n logging      -f helm-values/loki-stack-values.yaml

# 6. Microservices
helm install api       ./charts/api       -n app
helm install indexer   ./charts/indexer   -n app
helm install frontend  ./charts/frontend  -n app
helm install reporting ./charts/reporting -n app

# 7. Ingress
kubectl apply -f k8s/ingress/ingress.yaml

# 8. Vérifier que tout est Running
kubectl get pods -n app
kubectl get pods -n databases
```

### Attendre la disponibilité des bases de données

```bash
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=mysql         -n databases --timeout=300s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=rabbitmq      -n databases --timeout=300s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=elasticsearch -n databases --timeout=300s
```

---

## Accès aux services

### Application principale

```bash
# Récupérer l'IP externe du LoadBalancer
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Tester l'accès
curl http://<EXTERNAL_IP>/api/health
curl http://<EXTERNAL_IP>/
```

| Service | URL |
|---------|-----|
| Frontend | `http://<EXTERNAL_IP>/` |
| API Health | `http://<EXTERNAL_IP>/api/health` |
| API Metrics | `http://<EXTERNAL_IP>/api/metrics` |

### Grafana (monitoring)

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Récupérer le mot de passe admin
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

Ouvrir : `http://localhost:3000` — login : `admin` / mot de passe récupéré ci-dessus

### RabbitMQ Management UI

```bash
kubectl port-forward -n databases svc/rabbitmq 15672:15672
# Ouvrir http://localhost:15672
```

### Prometheus

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Ouvrir http://localhost:9090
```

---

## RBAC — Rôles et utilisateurs

Deux rôles sont configurés :

| Rôle | Scope | Permissions |
|------|-------|-------------|
| `sysadmin` | Cluster entier (ClusterRole) | Accès complet à toutes les ressources |
| `developer` | Namespace `app` uniquement (Role) | Lecture pods/services/deployments — **pas d'accès aux Secrets** |

### Obtenir les tokens

```bash
# Token sysadmin
kubectl create token sysadmin-user -n kube-system --duration=24h

# Token developer
kubectl create token developer-user -n app --duration=24h
```

### Créer un kubeconfig par rôle

```bash
# Exemple pour developer
CLUSTER=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
TOKEN=$(kubectl create token developer-user -n app --duration=24h)

kubectl config set-cluster kubiquest-cluster --server=$SERVER --insecure-skip-tls-verify=true
kubectl config set-credentials developer-user --token=$TOKEN
kubectl config set-context developer-ctx --cluster=kubiquest-cluster --user=developer-user --namespace=app
kubectl config use-context developer-ctx
```

### Vérifier les permissions (démo soutenance)

```bash
# developer NE PEUT PAS accéder aux secrets
kubectl auth can-i get secrets -n app --as=system:serviceaccount:app:developer-user
# Attendu : no

# developer PEUT voir les pods
kubectl auth can-i get pods -n app --as=system:serviceaccount:app:developer-user
# Attendu : yes

# developer NE PEUT PAS agir dans d'autres namespaces
kubectl auth can-i get pods -n databases --as=system:serviceaccount:app:developer-user
# Attendu : no
```

---

## Scripts de démonstration

### Autoscaling (HPA)

```bash
# Lance une avalanche de requêtes → déclenche l'autoscaling
./scripts/load-test.sh http://<EXTERNAL_IP> 120

# Dans un autre terminal, observer le scale-up
kubectl get hpa -n app -w
```

### Rolling Update Zero-Downtime

```bash
# Démontre un déploiement sans interruption de service
./scripts/zero-downtime-demo.sh http://<EXTERNAL_IP> v2.0.0

# Résultat : 0 requête en erreur pendant le rollout
```

### Déploiement cassé + Rollback

```bash
# Déploie une image brisée → les anciens pods continuent de servir
# Puis effectue un rollback automatique
./scripts/rollback-demo.sh http://<EXTERNAL_IP>
```

### Test manuel du job Reporting

```bash
# Déclencher le CronJob manuellement (sans attendre minuit)
kubectl create job --from=cronjob/reporting-cronjob test-reporting-$(date +%s) -n app

# Voir les logs du job
kubectl logs -n app -l job-name=test-reporting-<timestamp>
```

### Tolérance aux pannes — Simulation d'une panne de noeud

```bash
# Identifier un noeud
kubectl get nodes

# Cordonner (empêcher les nouveaux pods) + drainer
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Vérifier que l'application reste disponible
curl http://<EXTERNAL_IP>/api/health

# Remettre le noeud en service
kubectl uncordon <node-name>
```

---

## Rollback

### Via Helm

```bash
# Voir l'historique des déploiements
helm history api -n app

# Rollback à la revision précédente
helm rollback api -n app

# Rollback à une revision spécifique
helm rollback api 2 -n app
```

### Via kubectl

```bash
# Voir l'historique
kubectl rollout history deployment/api-deployment -n app

# Rollback immédiat
kubectl rollout undo deployment/api-deployment -n app
```

---

## Monitoring & Logs

### Métriques Prometheus

Les ServiceMonitors sont configurés pour scraper :

| Service | Endpoint | Métriques |
|---------|----------|-----------|
| API Laravel | `/api/metrics` | `kubiquest_products_total`, `kubiquest_mysql_up`, `kubiquest_api_info` |
| Indexer Node.JS | `/metrics` | `indexer_messages_processed_total`, `indexer_messages_failed_total`, `indexer_elasticsearch_up`, métriques Node.js |
| cAdvisor (bonus) | `:8080/metrics` | CPU/RAM par container et par noeud |

### Dashboards Grafana recommandés

| Dashboard | Source |
|-----------|--------|
| Kubernetes Cluster Overview | Intégré (kube-prometheus-stack) |
| Node Exporter Full | Grafana.com ID `1860` |
| MySQL Overview | Grafana.com ID `7362` |
| RabbitMQ Overview | Grafana.com ID `10991` |
| Elasticsearch Overview | Grafana.com ID `14191` |
| KubiQuest Apps | Custom (importer depuis Grafana UI) |

### Logs Loki

Dans Grafana → Explore → datasource Loki :

```logql
# Logs de l'API
{namespace="app", app_kubernetes_io_name="api"}

# Logs de l'indexer
{namespace="app", app_kubernetes_io_name="indexer"}

# Erreurs uniquement
{namespace="app"} |= "error"
```

---

## Bonus

### 16.1 — Let's Encrypt avec cert-manager

```bash
# 1. Installer cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true

# 2. Éditer l'email dans bonus/cert-manager/cluster-issuer.yaml
# 3. Appliquer les issuers
kubectl apply -f bonus/cert-manager/cluster-issuer.yaml

# 4. Remplacer le domaine dans bonus/cert-manager/ingress-tls.yaml
# 5. Déployer l'Ingress TLS (remplace k8s/ingress/ingress.yaml)
kubectl apply -f bonus/cert-manager/ingress-tls.yaml
```

### 16.2 — Environnement staging avec Kustomize

```bash
# Créer le namespace staging
kubectl create namespace staging

# Déployer l'overlay staging (replicas=1, images tag=staging, resources réduits)
kubectl apply -k bonus/kustomize/overlays/staging/

# Vérifier
kubectl get pods -n staging
```

### 16.3 — cAdvisor

```bash
# Déployer cAdvisor en DaemonSet dans le namespace monitoring
kubectl apply -f bonus/cadvisor/ -n monitoring

# Vérifier que le ServiceMonitor est scrappé par Prometheus
kubectl get servicemonitor -n monitoring
```

### 16.4 — Istio Service Mesh

```bash
# 1. Installer Istio
istioctl install --set profile=default -y

# 2. Activer l'injection automatique des sidecars dans le namespace app
kubectl label namespace app istio-injection=enabled

# 3. Redémarrer les pods pour injecter les sidecars Envoy
kubectl rollout restart deployment -n app

# 4. Appliquer la configuration Istio
kubectl apply -f bonus/istio/ -n app

# 5. Vérifier les sidecars (2 containers par pod)
kubectl get pods -n app

# 6. Vérifier mTLS (Kiali)
istioctl dashboard kiali
```

### 16.5 — CI/CD GitHub Actions

Le workflow est dans `bonus/ci/.github/workflows/ci-cd.yaml`.

Pour l'activer :
1. Copier le fichier dans `.github/workflows/ci-cd.yaml` à la racine du repo
2. Configurer les secrets GitHub (Settings → Secrets → Actions) :
   - `GHCR_TOKEN` : PAT avec `write:packages`
   - `KUBECONFIG_DATA` : `base64 -w 0 ~/.kube/config`

Le pipeline comprend 3 jobs :
- **build-and-push** : build en matrix (4 services) avec tags SHA + latest/staging
- **helm-lint** : `helm lint` + `helm install --dry-run` sur les 4 charts
- **deploy-staging** : `helm upgrade --install` avec le SHA du commit

---

## Structure du projet

```
KubiQuest/
│
├── frontend/                  # Angular 17 SPA
│   └── src/app/
│       ├── components/        # health, product-list, product-card, add-product
│       ├── services/          # api.service.ts
│       └── models/            # product.model.ts, health.model.ts
│
├── api/                       # Laravel 11 REST API
│   ├── app/Http/Controllers/  # Health, Product, Search, Metrics
│   ├── app/Services/          # RabbitMQService, ElasticsearchService
│   └── database/migrations/
│
├── indexer/                   # Node.JS RabbitMQ → Elasticsearch consumer
│   └── src/                   # index.js, consumer.js, elasticsearch.js, health.js, metrics.js
│
├── reporting/                 # Go CronJob → MySQL → MS Teams
│   └── main.go
│
├── charts/                    # Helm charts custom (un par microservice)
│   ├── frontend/
│   ├── api/
│   ├── indexer/
│   └── reporting/
│
├── k8s/                       # Manifests Kubernetes bruts
│   ├── namespaces/            # namespaces.yaml, limitrange, resourcequota
│   ├── rbac/                  # sysadmin + developer roles & bindings
│   ├── secrets/               # mysql, rabbitmq, elasticsearch, msteams, api, registry
│   └── ingress/               # ingress.yaml
│
├── helm-values/               # Values pour les charts Helm publics
│   ├── mysql-values.yaml
│   ├── rabbitmq-values.yaml
│   ├── elasticsearch-values.yaml
│   ├── ingress-nginx-values.yaml
│   ├── kube-prometheus-stack-values.yaml
│   └── loki-stack-values.yaml
│
├── docker/                    # Dockerfiles multi-stage
│   ├── frontend/              # node:20-alpine → nginx:alpine
│   ├── api/                   # composer:2 → php:8.2-fpm-alpine
│   ├── indexer/               # node:20-alpine (multi-stage)
│   └── reporting/             # golang:1.22-alpine → scratch
│
├── scripts/                   # Scripts de déploiement et démonstration
│   ├── deploy-all.sh          # Déploiement complet en une commande
│   ├── build-and-push.sh      # Build & push des 4 images Docker
│   ├── load-test.sh           # Test de charge → déclenche HPA
│   ├── zero-downtime-demo.sh  # Rolling update sans coupure
│   └── rollback-demo.sh       # Déploiement cassé + rollback
│
├── bonus/                     # Fonctionnalités bonus
│   ├── cert-manager/          # Let's Encrypt ClusterIssuer + Ingress TLS
│   ├── kustomize/             # Base + overlay staging
│   ├── cadvisor/              # DaemonSet + ServiceMonitor
│   ├── istio/                 # Gateway + VirtualService + mTLS
│   └── ci/                    # GitHub Actions CI/CD workflow
│
├── .dockerignore
├── .gitignore
├── docker-compose.dev.yml     # Environnement de dev local (MySQL + RabbitMQ + ES)
└── README.md
```

---

## Checklist de validation avant soutenance

### Fonctionnel
- [ ] Frontend accessible et fonctionnel (CRUD produits)
- [ ] Recherche de produits via Elasticsearch (`/api/search?q=…`)
- [ ] Indexation automatique lors de la création/suppression (vérifier dans ES)
- [ ] CronJob reporting testé manuellement → message reçu sur MS Teams

### Infrastructure
- [ ] Helm chart custom pour chaque microservice (frontend, api, indexer, reporting)
- [ ] Helm chart public pour MySQL, RabbitMQ, Elasticsearch, Ingress NGINX, Prometheus, Loki
- [ ] Ingress NGINX comme point d'entrée unique
- [ ] Images Docker sur ghcr.io (registre privé)

### Sécurité & Resource Management
- [ ] Resource requests et limits sur tous les pods
- [ ] Tous les mots de passe dans des Secrets K8s (jamais en clair dans Git)
- [ ] Role `sysadmin` démontré (accès total)
- [ ] Role `developer` démontré (pas d'accès aux Secrets)
- [ ] Labels cohérents sur toutes les ressources

### Haute Disponibilité
- [ ] Min 2 replicas pour frontend et API
- [ ] HPA déclenché et démontré (load-test.sh)
- [ ] PDB configuré (kubectl get pdb -n app)
- [ ] Rolling update zero-downtime démontré
- [ ] Déploiement cassé + rollback démontré
- [ ] Panne noeud simulée → app reste disponible

### Monitoring & Logs
- [ ] Prometheus scrape les métriques (ServiceMonitors actifs)
- [ ] Grafana accessible avec dashboards
- [ ] Logs disponibles dans Grafana via Loki

---

## Auteur

| Champ | Valeur |
|-------|--------|
| Projet | T-CLO-902 — KubiQuest |
| Promo | Epitech 2026 — Module Cloud T10 |
| Type | Projet solo |
| Repo | `KubiQuest` |
