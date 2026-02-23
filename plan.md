# Plan de Réalisation — KubiQuest (T-CLO-902)
> Epitech — T10 Cloud — Version 0.4.1
> Déploiement d'une app e-commerce microservices dans Kubernetes

---

## Table des matières

1. [Phase 0 — Analyse & Compréhension du projet](#phase-0)
2. [Phase 1 — Structure du dépôt Git](#phase-1)
3. [Phase 2 — Registre Docker privé (GitHub Container Registry)](#phase-2)
4. [Phase 3 — Dockerisation des applications](#phase-3)
5. [Phase 4 — Provisionnement du cluster Kubernetes Cloud](#phase-4)
6. [Phase 5 — Namespaces & RBAC (rôles et utilisateurs)](#phase-5)
7. [Phase 6 — Secrets Kubernetes](#phase-6)
8. [Phase 7 — Conventions de nommage et labels](#phase-7)
9. [Phase 8 — Infrastructure via Helm (packages publics)](#phase-8)
10. [Phase 9 — Helm Charts custom pour les microservices](#phase-9)
11. [Phase 10 — Ingress & Load Balancer](#phase-10)
12. [Phase 11 — Resource Management (limites et requests)](#phase-11)
13. [Phase 12 — Haute Disponibilité & Résilience](#phase-12)
14. [Phase 13 — Monitoring (Prometheus + Grafana)](#phase-13)
15. [Phase 14 — Log Aggregation](#phase-14)
16. [Phase 15 — Scripts de démonstration](#phase-15)
17. [Phase 16 — Bonus](#phase-16)
18. [Phase 17 — Documentation & Livraison](#phase-17)

---

## Architecture de référence

```
              [Actor / Browser]
                     |
             [Ingress / Load Balancer]  ← single entrypoint
                     |
            [Frontend — Angular]
                     |
           ┌─────────┴─────────┐
           |                   |
    [API — Laravel]     [API — Laravel]   ← repliqué
     |     |     |
  [MySQL] [RabbitMQ] [Elasticsearch]
                |
         [Indexer — Node.JS]

  [Reporting Job — Go]  → cron midnight → MySQL → MS Teams webhook

```

**Flux de données :**
1. Frontend → API : création / suppression de produits
2. API → RabbitMQ exchange : publication des changements produits
3. Indexer → RabbitMQ queue : consommation → index Elasticsearch
4. Frontend → API → Elasticsearch : recherche de produits
5. Reporting (Go CronJob) → MySQL → Microsoft Teams webhook (minuit)

---

## Phase 0 — Analyse & Compréhension du projet {#phase-0}

### 0.1 — Inventaire des applications à déployer

| Service       | Technologie | Type K8s      | Réplication | Base de données |
|---------------|-------------|---------------|-------------|-----------------|
| frontend      | Angular     | Deployment    | Oui         | —               |
| api           | Laravel/PHP | Deployment    | Oui         | MySQL, Elasticsearch |
| indexer       | Node.JS     | Deployment    | Possible    | RabbitMQ, Elasticsearch |
| reporting     | Go          | CronJob       | Non         | MySQL           |
| mysql         | MySQL       | StatefulSet   | Non (primary) | —             |
| rabbitmq      | RabbitMQ    | StatefulSet   | Oui (cluster) | —             |
| elasticsearch | Elasticsearch | StatefulSet | Oui (cluster) | —           |

### 0.2 — Inventaire des services d'infrastructure

| Service              | Outil                    | Déployé via      |
|----------------------|--------------------------|------------------|
| Load Balancer        | ingress-nginx            | Helm public      |
| Monitoring           | kube-prometheus-stack    | Helm public      |
| Log Aggregation      | Loki + Promtail          | Helm public      |
| Registry             | GitHub Container Registry | GitHub Actions  |

### 0.3 — Choix technologiques à valider en équipe avant de démarrer

- **Cloud provider** : GKE (Google), EKS (AWS) ou AKS (Azure) — recommandé GKE pour la facilité de provisionning
- **Log aggregation** : Loki + Promtail (stack légère) ou EFK (Elasticsearch + Fluentd + Kibana) — recommandé Loki car Elasticsearch est déjà utilisé par l'app
- **Stratégie zero-downtime** : Rolling Update (natif K8s) — simple et suffisant pour la démo
- **Staging bonus** : Kustomize avec un overlay `staging/` séparé

---

## Phase 1 — Structure du dépôt Git {#phase-1}

### 1.1 — Initialisation du dépôt

- Créer le dépôt GitHub avec le nom : `T-CLO-902-<GroupName>`
- Initialiser avec un `.gitignore` adapté (exclure : binaires, `.env`, `node_modules`, `vendor`, `*.log`)
- Créer la branche principale `main`
- Inviter le professeur en accès collaborateur

### 1.2 — Arborescence complète du projet

```
T-CLO-902-<GroupName>/
│
├── charts/                        # Helm charts CUSTOM (un par microservice)
│   ├── frontend/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── hpa.yaml
│   │       ├── pdb.yaml
│   │       └── _helpers.tpl
│   ├── api/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── hpa.yaml
│   │       ├── pdb.yaml
│   │       └── _helpers.tpl
│   ├── indexer/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── hpa.yaml
│   │       ├── pdb.yaml
│   │       └── _helpers.tpl
│   └── reporting/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── cronjob.yaml
│           └── _helpers.tpl
│
├── k8s/                           # Manifests Kubernetes bruts (non-Helm)
│   ├── namespaces/
│   │   └── namespaces.yaml        # Déclaration des namespaces
│   ├── rbac/
│   │   ├── sysadmin-role.yaml
│   │   ├── sysadmin-binding.yaml
│   │   ├── developer-role.yaml
│   │   ├── developer-binding.yaml
│   │   ├── sysadmin-user.yaml
│   │   └── developer-user.yaml
│   └── secrets/
│       ├── mysql-secret.yaml
│       ├── rabbitmq-secret.yaml
│       ├── elasticsearch-secret.yaml
│       ├── msteams-secret.yaml
│       └── registry-secret.yaml   # imagePullSecret pour ghcr.io
│
├── helm-values/                   # Values files pour les charts Helm publics
│   ├── mysql-values.yaml
│   ├── rabbitmq-values.yaml
│   ├── elasticsearch-values.yaml
│   ├── ingress-nginx-values.yaml
│   ├── kube-prometheus-stack-values.yaml
│   └── loki-stack-values.yaml
│
├── docker/                        # Dockerfiles pour chaque application
│   ├── frontend/
│   │   └── Dockerfile
│   ├── api/
│   │   └── Dockerfile
│   ├── indexer/
│   │   └── Dockerfile
│   └── reporting/
│       └── Dockerfile
│
├── scripts/                       # Scripts de démonstration pour la soutenance
│   ├── deploy-all.sh              # Déploie toute la stack en une commande
│   ├── load-test.sh               # Génère du trafic pour tester l'autoscaling
│   ├── rollback-demo.sh           # Déploie une image cassée puis rollback
│   └── zero-downtime-demo.sh      # Démontre un rolling update sans coupure
│
├── bonus/                         # Répertoire bonus (obligatoire selon le sujet)
│   ├── kustomize/
│   │   ├── base/                  # Base commune
│   │   └── overlays/
│   │       └── staging/           # Overlay staging
│   ├── cert-manager/              # Let's Encrypt
│   ├── cadvisor/                  # cAdvisor
│   ├── istio/                     # Istio service mesh
│   └── ci/
│       └── .github/workflows/     # GitHub Actions CI/CD
│
└── README.md                      # Documentation principale
```

---

## Phase 2 — Registre Docker privé (GitHub Container Registry) {#phase-2}

### 2.1 — Configuration du registre ghcr.io

- Activer GitHub Container Registry (ghcr.io) sur le dépôt GitHub
- Générer un **Personal Access Token (PAT)** GitHub avec les scopes :
  - `read:packages`
  - `write:packages`
  - `delete:packages`
- Stocker ce token comme **GitHub Secret** (`GHCR_TOKEN`) pour les GitHub Actions

### 2.2 — Nommage des images Docker

Convention de nommage des images :
```
ghcr.io/<org>/<repo>/frontend:latest
ghcr.io/<org>/<repo>/api:latest
ghcr.io/<org>/<repo>/indexer:latest
ghcr.io/<org>/<repo>/reporting:latest
```

### 2.3 — Secret Kubernetes pour le pull d'images

- Créer un secret de type `kubernetes.io/dockerconfigjson` dans chaque namespace applicatif
- Ce secret sera référencé dans les `imagePullSecrets` de chaque Deployment

---

## Phase 3 — Dockerisation des applications {#phase-3}

### 3.1 — Dockerfile Frontend (Angular)

**Stratégie** : Multi-stage build
- **Stage 1 (builder)** : image `node:20-alpine` — installer les dépendances npm, exécuter `ng build --configuration production`
- **Stage 2 (runner)** : image `nginx:alpine` — copier le dossier `dist/` depuis le builder dans `/usr/share/nginx/html`
- Ajouter un fichier `nginx.conf` custom pour :
  - Gérer le routing SPA Angular (fallback vers `index.html`)
  - Proxy pass vers l'API sur `/api`
- Exposer le port `80`
- S'assurer que l'image finale est aussi légère que possible (pas de node_modules dans l'image finale)

### 3.2 — Dockerfile API (Laravel / PHP)

**Stratégie** : Multi-stage build
- **Stage 1 (builder)** : image `composer:latest` — copier `composer.json` / `composer.lock`, exécuter `composer install --no-dev --optimize-autoloader`
- **Stage 2 (runner)** : image `php:8.2-fpm-alpine`
  - Installer les extensions PHP nécessaires : `pdo_mysql`, `mbstring`, `openssl`, `redis` (si nécessaire), `zip`
  - Copier le code de l'application et le dossier `vendor/` depuis le builder
  - Copier un `php-fpm.conf` et `www.conf` optimisés
  - Ajouter un processus nginx ou utiliser `php artisan serve` (préférer nginx + php-fpm)
  - Exposer le port `80`
- Variables d'environnement attendues : `DB_HOST`, `DB_PASSWORD`, `RABBITMQ_HOST`, `RABBITMQ_PASSWORD`, `ELASTICSEARCH_HOST`, `APP_KEY`
- Le container doit exécuter les migrations au démarrage (`php artisan migrate --force`) via un `initContainer` ou un script `entrypoint.sh`

### 3.3 — Dockerfile Indexer (Node.JS)

**Stratégie** : Multi-stage build
- **Stage 1 (builder)** : image `node:20-alpine` — copier `package.json` / `package-lock.json`, exécuter `npm ci --only=production`
- **Stage 2 (runner)** : image `node:20-alpine`
  - Copier les `node_modules/` depuis le builder
  - Copier le code source
  - Exécuter sous un utilisateur non-root (`node`)
  - Exposer un port de health check si l'indexer en expose un
- Variables d'environnement attendues : `RABBITMQ_HOST`, `RABBITMQ_PASSWORD`, `RABBITMQ_QUEUE`, `ELASTICSEARCH_HOST`

### 3.4 — Dockerfile Reporting Job (Go)

**Stratégie** : Multi-stage build
- **Stage 1 (builder)** : image `golang:1.22-alpine`
  - Copier `go.mod` / `go.sum`, exécuter `go mod download`
  - Copier le code source, compiler avec `CGO_ENABLED=0 GOOS=linux go build -o /reporting ./...`
- **Stage 2 (runner)** : image `scratch` ou `alpine:3.19` (scratch = image la plus petite possible)
  - Copier uniquement le binaire compilé depuis le builder
  - Définir l'entrypoint sur le binaire
- Variables d'environnement attendues : `DB_HOST`, `DB_PASSWORD`, `MSTEAMS_WEBHOOK_URL`

### 3.5 — Build & Push des images

- Construire localement chaque image pour valider qu'elle build correctement
- Tagger et pusher vers ghcr.io pour chacune des 4 images
- Valider que chaque image est accessible en privé sur ghcr.io

---

## Phase 4 — Provisionnement du cluster Kubernetes Cloud {#phase-4}

### 4.1 — Choix et création du cluster

**Recommandé : GKE (Google Kubernetes Engine)**

Spécifications du cluster pour la soutenance (cluster "frais") :
- **Minimum 3 nodes** (pour démontrer la tolérance aux pannes de noeud)
- Type de machine : `e2-standard-2` (2 vCPU, 8 GB RAM) ou supérieur
- Zone : choisir une région unique pour simplifier
- Activer le **Cluster Autoscaler** (min: 3, max: 6 nodes)
- Activer les **Workload Identity** si besoin de RBAC fin

### 4.2 — Configuration de kubectl en local

- Récupérer le kubeconfig du cluster cloud
- Configurer `kubectl` pour pointer vers le bon cluster (`kubectl config use-context ...`)
- Vérifier la connexion : `kubectl cluster-info` et `kubectl get nodes`

### 4.3 — Installation des outils nécessaires en local

- `kubectl` (dernière version stable)
- `helm` v3 (dernière version stable)
- `docker` (pour build et push des images)
- `git`
- `k9s` (optionnel mais très utile pour la démo)

---

## Phase 5 — Namespaces & RBAC {#phase-5}

### 5.1 — Définition des namespaces

Créer les namespaces suivants (fichier `k8s/namespaces/namespaces.yaml`) :

| Namespace       | Usage                                       |
|-----------------|---------------------------------------------|
| `app`           | Frontend, API, Indexer, Reporting           |
| `databases`     | MySQL, RabbitMQ, Elasticsearch              |
| `monitoring`    | Prometheus, Grafana                         |
| `logging`       | Loki, Promtail                              |
| `ingress-nginx` | Ingress Controller                          |

### 5.2 — Définition des rôles RBAC

**Rôle `sysadmin`** (fichier `k8s/rbac/sysadmin-role.yaml`)
- Scope : `ClusterRole` (accès à tous les namespaces)
- Permissions :
  - `verbs: ["*"]` sur toutes les ressources (`"*"`)
  - Accès complet aux `secrets`, `pods`, `deployments`, `services`, `nodes`, `persistentvolumes`
  - Accès aux ressources de monitoring et logging

**Rôle `developer`** (fichier `k8s/rbac/developer-role.yaml`)
- Scope : `Role` limité au namespace `app`
- Permissions :
  - `get`, `list`, `watch` sur `pods`, `deployments`, `services`, `replicasets`
  - `get`, `list`, `watch`, `create`, `update`, `patch` sur `deployments` (pour déployer)
  - **Interdit** : accès aux `secrets`, aux autres namespaces, aux `nodes`

### 5.3 — Création des utilisateurs et bindings

- **Utilisateur sysadmin** : créer un `ServiceAccount` `sysadmin-user` dans le namespace `kube-system`, créer un `ClusterRoleBinding` qui lie `sysadmin-user` au `ClusterRole sysadmin`
- **Utilisateur developer** : créer un `ServiceAccount` `developer-user` dans le namespace `app`, créer un `RoleBinding` qui lie `developer-user` au `Role developer` dans le namespace `app`
- Générer les kubeconfigs pour chaque utilisateur (token-based) pour pouvoir les démontrer
- Vérifier les permissions avec `kubectl auth can-i --as=system:serviceaccount:app:developer-user get secrets -n app` (doit retourner `no`)

---

## Phase 6 — Secrets Kubernetes {#phase-6}

### 6.1 — Règles générales

- Tous les mots de passe et tokens **doivent** être dans des `Secret` Kubernetes, jamais en clair dans les `values.yaml` ou les `Dockerfile`
- Les secrets sont encodés en base64 dans les manifests YAML
- **Ne jamais commiter de secrets décodés dans le dépôt Git**
- Pour la soutenance, utiliser des secrets générés au moment du déploiement (via script)

### 6.2 — Liste des secrets à créer

**`k8s/secrets/mysql-secret.yaml`**
- Clé `MYSQL_ROOT_PASSWORD` : mot de passe root MySQL
- Clé `MYSQL_PASSWORD` : mot de passe utilisateur applicatif MySQL
- Clé `MYSQL_DATABASE` : nom de la base de données
- Clé `MYSQL_USER` : nom de l'utilisateur applicatif

**`k8s/secrets/rabbitmq-secret.yaml`**
- Clé `RABBITMQ_DEFAULT_USER` : utilisateur RabbitMQ
- Clé `RABBITMQ_DEFAULT_PASS` : mot de passe RabbitMQ

**`k8s/secrets/elasticsearch-secret.yaml`**
- Clé `ELASTICSEARCH_PASSWORD` : mot de passe Elasticsearch
- Clé `ELASTICSEARCH_USER` : utilisateur Elasticsearch (si activé)

**`k8s/secrets/msteams-secret.yaml`**
- Clé `MSTEAMS_WEBHOOK_URL` : URL du webhook Microsoft Teams

**`k8s/secrets/registry-secret.yaml`**
- Type : `kubernetes.io/dockerconfigjson`
- Contenu : credentials ghcr.io pour le pull des images privées
- Doit être créé dans chaque namespace qui pull des images (`app`)

**`k8s/secrets/api-secret.yaml`**
- Clé `APP_KEY` : clé Laravel (`base64:...`)

### 6.3 — Référencement des secrets dans les Deployments

- Utiliser `envFrom.secretRef` pour injecter les secrets comme variables d'environnement dans les pods
- Ne jamais passer les valeurs de secrets en argument de commande (visible dans `ps aux`)

---

## Phase 7 — Conventions de nommage et labels {#phase-7}

### 7.1 — Labels obligatoires sur toutes les ressources

Toutes les ressources Kubernetes (Deployments, Services, Pods, PersistentVolumeClaims...) doivent avoir les labels suivants :

```yaml
labels:
  app.kubernetes.io/name: <nom-du-service>         # ex: "api", "frontend", "mysql"
  app.kubernetes.io/part-of: kubiquest             # projet
  app.kubernetes.io/managed-by: helm               # ou "kubectl"
  app.kubernetes.io/version: "1.0.0"               # version de l'image
  environment: production                           # ou "staging" pour le bonus
```

### 7.2 — Convention de nommage des ressources

- Deployments : `<service>-deployment` → ex: `api-deployment`
- Services : `<service>-service` → ex: `api-service`
- ConfigMaps : `<service>-config` → ex: `api-config`
- Secrets : `<service>-secret` → ex: `mysql-secret`
- HPA : `<service>-hpa` → ex: `api-hpa`
- PDB : `<service>-pdb` → ex: `api-pdb`

### 7.3 — Sélecteurs

Les `selector` dans les Services et les Deployments doivent utiliser des labels stables (ne pas inclure `version`) :
```yaml
selector:
  app.kubernetes.io/name: api
  app.kubernetes.io/part-of: kubiquest
```

---

## Phase 8 — Infrastructure via Helm (packages publics) {#phase-8}

> Ces services sont déployés avec des charts Helm **publics** et leurs `values.yaml` custom se trouvent dans `helm-values/`.

### 8.1 — MySQL (Bitnami MySQL chart)

**Chart** : `bitnami/mysql`

**Fichier** : `helm-values/mysql-values.yaml`

Configuration à définir :
- `auth.existingSecret: mysql-secret` → utiliser le Secret K8s créé en Phase 6
- `auth.database: kubiquest` → nom de la base
- `primary.persistence.size: 10Gi`
- `primary.resources.requests.memory: 256Mi`, `cpu: 250m`
- `primary.resources.limits.memory: 512Mi`, `cpu: 500m`
- `primary.configuration` : activer `innodb_buffer_pool_size`, `max_connections` optimisés
- Labels cohérents via `commonLabels`
- Déployer dans le namespace `databases`

**Commande de déploiement** :
```
helm install mysql bitnami/mysql -n databases -f helm-values/mysql-values.yaml
```

### 8.2 — RabbitMQ (Bitnami RabbitMQ chart)

**Chart** : `bitnami/rabbitmq`

**Fichier** : `helm-values/rabbitmq-values.yaml`

Configuration à définir :
- `auth.existingPasswordSecret: rabbitmq-secret`
- `replicaCount: 3` → cluster RabbitMQ pour la HA
- `persistence.size: 5Gi`
- `resources.requests.memory: 256Mi`, `cpu: 250m`
- `resources.limits.memory: 512Mi`, `cpu: 500m`
- Activer le plugin RabbitMQ Management (interface web)
- Configurer le nom de l'exchange : `products` (exchange fanout)
- Configurer le nom de la queue : `products-indexer`
- Labels cohérents via `commonLabels`
- Déployer dans le namespace `databases`

**Commande de déploiement** :
```
helm install rabbitmq bitnami/rabbitmq -n databases -f helm-values/rabbitmq-values.yaml
```

### 8.3 — Elasticsearch (Bitnami ou Elastic Helm chart)

**Chart** : `bitnami/elasticsearch` (ou `elastic/elasticsearch`)

**Fichier** : `helm-values/elasticsearch-values.yaml`

Configuration à définir :
- `security.enabled: true` → activer l'authentification
- `security.existingSecret: elasticsearch-secret`
- `master.replicaCount: 1` (master node)
- `data.replicaCount: 2` (data nodes pour la HA)
- `coordinating.replicaCount: 1`
- `master.resources.requests.memory: 512Mi`, `cpu: 500m`
- `master.resources.limits.memory: 1Gi`, `cpu: 1000m`
- `data.persistence.size: 10Gi`
- `clusterName: kubiquest-es`
- Labels cohérents
- Déployer dans le namespace `databases`

**Commande de déploiement** :
```
helm install elasticsearch bitnami/elasticsearch -n databases -f helm-values/elasticsearch-values.yaml
```

### 8.4 — Ingress NGINX (ingress-nginx chart)

**Chart** : `ingress-nginx/ingress-nginx`

**Fichier** : `helm-values/ingress-nginx-values.yaml`

Configuration à définir :
- `controller.replicaCount: 2` → HA de l'ingress
- `controller.resources.requests.memory: 128Mi`, `cpu: 100m`
- `controller.resources.limits.memory: 256Mi`, `cpu: 500m`
- `controller.service.type: LoadBalancer` → expose une IP externe
- Labels cohérents
- Déployer dans le namespace `ingress-nginx`

**Commande de déploiement** :
```
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx -f helm-values/ingress-nginx-values.yaml
```

### 8.5 — Monitoring : kube-prometheus-stack

**Chart** : `prometheus-community/kube-prometheus-stack`

**Fichier** : `helm-values/kube-prometheus-stack-values.yaml`

Configuration à définir :
- `prometheus.prometheusSpec.resources.requests.memory: 512Mi`
- `prometheus.prometheusSpec.resources.limits.memory: 1Gi`
- `grafana.adminPassword` → référencer un secret K8s
- `grafana.persistence.enabled: true`, `grafana.persistence.size: 5Gi`
- `grafana.resources.requests.memory: 128Mi`
- `grafana.resources.limits.memory: 256Mi`
- `alertmanager.enabled: true`
- Activer la collecte des métriques sur tous les namespaces
- Labels cohérents
- Déployer dans le namespace `monitoring`

**Commande de déploiement** :
```
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f helm-values/kube-prometheus-stack-values.yaml
```

### 8.6 — Log Aggregation : Loki Stack

**Chart** : `grafana/loki-stack`

**Fichier** : `helm-values/loki-stack-values.yaml`

Configuration à définir :
- `loki.enabled: true`
- `promtail.enabled: true` → collecte les logs de tous les pods automatiquement
- `loki.persistence.enabled: true`, `loki.persistence.size: 10Gi`
- `loki.resources.requests.memory: 256Mi`
- `loki.resources.limits.memory: 512Mi`
- Configurer Loki comme datasource dans Grafana (via `grafana.additionalDataSources`)
- Déployer dans le namespace `logging`

**Commande de déploiement** :
```
helm install loki-stack grafana/loki-stack -n logging -f helm-values/loki-stack-values.yaml
```

---

## Phase 9 — Helm Charts custom pour les microservices {#phase-9}

> Un chart Helm custom est créé pour chaque microservice. Ils doivent être **réutilisables et paramétrables** (image, variables d'env, replicas, resources...).

### Structure commune de chaque chart

Chaque chart contient :
- **`Chart.yaml`** : métadonnées (name, version, description, appVersion)
- **`values.yaml`** : valeurs par défaut (image, tag, replicas, resources, env, etc.)
- **`templates/_helpers.tpl`** : fonctions de template réutilisables (fullname, labels, selectorLabels)
- **`templates/deployment.yaml`** : Deployment (ou CronJob pour reporting)
- **`templates/service.yaml`** : Service ClusterIP
- **`templates/hpa.yaml`** : HorizontalPodAutoscaler
- **`templates/pdb.yaml`** : PodDisruptionBudget

### 9.1 — Chart `frontend` (Angular)

**`values.yaml`** doit exposer :
- `image.repository`, `image.tag`, `image.pullPolicy`
- `replicaCount: 2`
- `service.type: ClusterIP`, `service.port: 80`
- `resources.requests.memory: 64Mi`, `resources.requests.cpu: 50m`
- `resources.limits.memory: 128Mi`, `resources.limits.cpu: 200m`
- `autoscaling.enabled: true`, `autoscaling.minReplicas: 2`, `autoscaling.maxReplicas: 5`, `autoscaling.targetCPUUtilizationPercentage: 70`
- `imagePullSecrets: [{name: registry-secret}]`
- `nodeSelector: {}`, `tolerations: []`, `affinity: {}`

**`templates/deployment.yaml`** doit inclure :
- `strategy.type: RollingUpdate` avec `maxSurge: 1`, `maxUnavailable: 0`
- `readinessProbe` : HTTP GET `/` port `80`, `initialDelaySeconds: 10`, `periodSeconds: 5`
- `livenessProbe` : HTTP GET `/` port `80`, `initialDelaySeconds: 30`, `periodSeconds: 10`
- Référence au `imagePullSecret` pour ghcr.io

**`templates/pdb.yaml`** :
- `minAvailable: 1` → au moins 1 pod frontend doit toujours être disponible

**Commande de déploiement** :
```
helm install frontend ./charts/frontend -n app -f charts/frontend/values.yaml
```

### 9.2 — Chart `api` (Laravel)

**`values.yaml`** doit exposer :
- `image.repository`, `image.tag`, `image.pullPolicy`
- `replicaCount: 2`
- `service.type: ClusterIP`, `service.port: 80`
- `resources.requests.memory: 256Mi`, `resources.requests.cpu: 250m`
- `resources.limits.memory: 512Mi`, `resources.limits.cpu: 500m`
- `autoscaling.enabled: true`, `autoscaling.minReplicas: 2`, `autoscaling.maxReplicas: 6`, `autoscaling.targetCPUUtilizationPercentage: 70`
- `env.DB_HOST`, `env.DB_DATABASE`, `env.DB_PORT`
- `existingSecrets: [mysql-secret, rabbitmq-secret, elasticsearch-secret, api-secret]`
- `imagePullSecrets: [{name: registry-secret}]`
- `initContainers.migrations.enabled: true` → exécuter `php artisan migrate --force` avant le démarrage du container principal

**`templates/deployment.yaml`** doit inclure :
- `initContainers` : container qui exécute les migrations Laravel (même image que l'API)
- `strategy.type: RollingUpdate` avec `maxSurge: 1`, `maxUnavailable: 0`
- `readinessProbe` : HTTP GET `/api/health` port `80`, `initialDelaySeconds: 20`
- `livenessProbe` : HTTP GET `/api/health` port `80`, `initialDelaySeconds: 60`
- Injection des secrets via `envFrom.secretRef`

**`templates/pdb.yaml`** :
- `minAvailable: 1`

**Commande de déploiement** :
```
helm install api ./charts/api -n app -f charts/api/values.yaml
```

### 9.3 — Chart `indexer` (Node.JS)

**`values.yaml`** doit exposer :
- `image.repository`, `image.tag`, `image.pullPolicy`
- `replicaCount: 1` (un seul consommateur RabbitMQ suffit, scalable si besoin)
- `service.enabled: false` (l'indexer ne reçoit pas de trafic HTTP entrant)
- `resources.requests.memory: 128Mi`, `resources.requests.cpu: 100m`
- `resources.limits.memory: 256Mi`, `resources.limits.cpu: 300m`
- `autoscaling.enabled: true`, `autoscaling.minReplicas: 1`, `autoscaling.maxReplicas: 3`
- `env.RABBITMQ_HOST`, `env.ELASTICSEARCH_HOST`
- `existingSecrets: [rabbitmq-secret, elasticsearch-secret]`
- `imagePullSecrets: [{name: registry-secret}]`

**`templates/deployment.yaml`** doit inclure :
- `strategy.type: RollingUpdate` avec `maxSurge: 1`, `maxUnavailable: 1` (un délai d'indexation est accepté)
- `readinessProbe` : TCP socket ou HTTP GET si l'indexer expose un port de santé
- `livenessProbe` : idem

**`templates/pdb.yaml`** :
- `minAvailable: 0` → tolérance à la perte de l'indexer (délai d'indexation accepté)

**Commande de déploiement** :
```
helm install indexer ./charts/indexer -n app -f charts/indexer/values.yaml
```

### 9.4 — Chart `reporting` (Go CronJob)

**`values.yaml`** doit exposer :
- `image.repository`, `image.tag`, `image.pullPolicy`
- `schedule: "0 0 * * *"` → minuit tous les jours
- `resources.requests.memory: 64Mi`, `resources.requests.cpu: 50m`
- `resources.limits.memory: 128Mi`, `resources.limits.cpu: 100m`
- `existingSecrets: [mysql-secret, msteams-secret]`
- `imagePullSecrets: [{name: registry-secret}]`
- `successfulJobsHistoryLimit: 3`
- `failedJobsHistoryLimit: 1`
- `concurrencyPolicy: Forbid` → ne pas lancer 2 jobs simultanément

**`templates/cronjob.yaml`** doit inclure :
- `spec.schedule` depuis `values.yaml`
- `spec.jobTemplate.spec.template.spec.restartPolicy: OnFailure`
- Injection des secrets via `envFrom.secretRef`

**Commande de déploiement** :
```
helm install reporting ./charts/reporting -n app -f charts/reporting/values.yaml
```

---

## Phase 10 — Ingress & Load Balancer {#phase-10}

### 10.1 — Architecture de l'Ingress

L'Ingress NGINX est le **point d'entrée unique** de l'infrastructure.

Règles de routing :
- `/` → Service `frontend-service` (port 80)
- `/api` → Service `api-service` (port 80)
- `/api/search` → Service `api-service` (port 80) — l'API fait proxy vers Elasticsearch

### 10.2 — Manifest Ingress

Créer un fichier `k8s/ingress/ingress.yaml` (ou inclure dans le chart `frontend`) :

```yaml
# Structure attendue — ne pas coder ici, juste le plan
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubiquest-ingress
  namespace: app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
  labels:
    app.kubernetes.io/part-of: kubiquest
spec:
  ingressClassName: nginx
  rules:
    - host: kubiquest.local  # remplacer par le DNS réel lors de la soutenance
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service: { name: api-service, port: { number: 80 } }
          - path: /
            pathType: Prefix
            backend:
              service: { name: frontend-service, port: { number: 80 } }
```

### 10.3 — Récupération de l'IP externe

Après déploiement, récupérer l'IP externe du LoadBalancer :
```
kubectl get svc -n ingress-nginx ingress-nginx-controller
```
Configurer le DNS ou les `/etc/hosts` pour pointer vers cette IP.

---

## Phase 11 — Resource Management (limites et requests) {#phase-11}

### 11.1 — Règle absolue

**Chaque container de chaque pod doit avoir `resources.requests` ET `resources.limits` définis.**

Sans cela : le scheduler ne peut pas placer les pods correctement et un pod peut monopoliser un noeud entier.

### 11.2 — LimitRange par namespace

Créer un `LimitRange` dans chaque namespace applicatif pour imposer des valeurs par défaut si un pod oublie de les définir :

```yaml
# Fichier: k8s/namespaces/limitrange-app.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: app
spec:
  limits:
    - type: Container
      default:
        memory: 256Mi
        cpu: 200m
      defaultRequest:
        memory: 128Mi
        cpu: 100m
      max:
        memory: 1Gi
        cpu: 1000m
```

### 11.3 — ResourceQuota par namespace

Créer un `ResourceQuota` pour éviter qu'un namespace consomme toutes les ressources du cluster :

```yaml
# Fichier: k8s/namespaces/resourcequota-app.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: app-quota
  namespace: app
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 4Gi
    limits.cpu: "8"
    limits.memory: 8Gi
    pods: "20"
```

---

## Phase 12 — Haute Disponibilité & Résilience {#phase-12}

### 12.1 — Réplication des services

| Service       | Min replicas | Max replicas | Justification                          |
|---------------|-------------|-------------|----------------------------------------|
| frontend      | 2           | 5           | Tolérance panne noeud + scalabilité     |
| api           | 2           | 6           | Tolérance panne noeud + scalabilité     |
| indexer       | 1           | 3           | Délai accepté, scalabilité lecture MQ   |
| reporting     | N/A (CronJob)| N/A        | Pas de réplication, job ponctuel        |
| ingress-nginx | 2           | —           | Tolérance panne noeud                   |
| rabbitmq      | 3           | —           | Cluster RabbitMQ natif                  |
| elasticsearch | 3 (master+data)| —        | Cluster ES natif                        |

### 12.2 — Horizontal Pod Autoscaler (HPA)

Pour `frontend`, `api` et `indexer`, configurer un HPA dans chaque chart custom :

```yaml
# Structure attendue pour chaque HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef: { ... }
  minReplicas: <valeur depuis values.yaml>
  maxReplicas: <valeur depuis values.yaml>
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70   # Scaler quand CPU > 70%
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

### 12.3 — Pod Disruption Budget (PDB)

Un PDB garantit qu'un minimum de pods reste disponible pendant les opérations de maintenance (drain de noeud, rolling update) :

- `frontend-pdb` : `minAvailable: 1`
- `api-pdb` : `minAvailable: 1`
- `indexer-pdb` : `minAvailable: 0` (délai d'indexation accepté)

### 12.4 — Anti-affinité des pods

Pour garantir que les pods d'un même Deployment ne soient pas tous sur le même noeud, ajouter une règle d'anti-affinité dans chaque chart :

```yaml
# Dans chaque deployment.yaml — structure attendue
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: <service>
          topologyKey: kubernetes.io/hostname
```

### 12.5 — Stratégie de déploiement Zero-Downtime (Rolling Update)

Pour chaque Deployment :
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # Peut créer 1 pod supplémentaire pendant le rollout
    maxUnavailable: 0  # Aucun pod ne peut être indisponible pendant le rollout
```

Avec des `readinessProbe` correctement configurées, le trafic n'est routé vers un nouveau pod que lorsqu'il est prêt → **zéro downtime garanti**.

### 12.6 — Probes (Readiness & Liveness)

**Readiness Probe** : détermine si le pod peut recevoir du trafic
- Configurée sur chaque service avec un délai suffisant pour le démarrage
- En cas d'échec, le pod est retiré du load balancer sans être redémarré

**Liveness Probe** : détermine si le container est vivant
- Délai plus long (`initialDelaySeconds`) pour ne pas killer un pod qui démarre
- En cas d'échec répété, Kubernetes redémarre le container

**Startup Probe** (optionnel) : pour les applications lentes à démarrer (Laravel, Elasticsearch) :
- Protège le pod des kills prématurés pendant la phase d'initialisation

---

## Phase 13 — Monitoring (Prometheus + Grafana) {#phase-13}

### 13.1 — Métriques collectées par défaut (kube-prometheus-stack)

Le chart `kube-prometheus-stack` installe automatiquement :
- Prometheus avec des ServiceMonitors pour les composants K8s
- Grafana avec des dashboards pré-configurés
- Alertmanager
- node-exporter (métriques OS des noeuds)
- kube-state-metrics (métriques des objets K8s)

### 13.2 — ServiceMonitors pour les applications custom

Pour que Prometheus collecte les métriques des applications custom, il faut :

- Ajouter une route `/metrics` exposant des métriques Prometheus format dans l'API Laravel (package `promphp/prometheus_client_php`)
- Ajouter une route `/metrics` dans l'Indexer Node.JS (package `prom-client`)
- Créer un `ServiceMonitor` pour chaque service dans le chart custom correspondant :

```yaml
# Structure attendue — templates/servicemonitor.yaml dans chaque chart
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: <service>
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

### 13.3 — Dashboards Grafana à créer/importer

Dashboards à configurer :
1. **Dashboard "Cluster Overview"** : CPU/RAM total, pods running/pending/failed, noeuds
2. **Dashboard "Application"** : Request rate, error rate, latency P50/P95/P99 par service
3. **Dashboard "Databases"** : Connexions MySQL actives, messages RabbitMQ en queue, documents Elasticsearch
4. **Dashboard "Autoscaling"** : Nombre de replicas par service au fil du temps
5. **Dashboard "Logs"** : Intégré avec Loki pour voir les logs directement dans Grafana

Les dashboards Bitnami MySQL, RabbitMQ et Elasticsearch peuvent être importés depuis Grafana.com (IDs publics).

### 13.4 — Alertes Prometheus

Configurer des alertes dans Alertmanager pour :
- Pod crash loop (redémarrages répétés)
- CPU utilization > 80% sur un noeud pendant 5 minutes
- Memory utilization > 85% sur un pod
- RabbitMQ queue depth > 1000 messages
- Elasticsearch cluster status = `red` ou `yellow`

---

## Phase 14 — Log Aggregation {#phase-14}

### 14.1 — Architecture Loki + Promtail

- **Promtail** : DaemonSet déployé sur chaque noeud, collecte les logs de tous les containers via les fichiers `/var/log/pods/`
- **Loki** : stockage et indexation des logs (chaque log est tagué avec le namespace, pod name, container name, labels K8s)
- **Grafana** : interface de visualisation et de recherche des logs via Loki datasource

### 14.2 — Validation du pipeline de logs

Vérifier que les logs de chaque service sont bien collectés et disponibles dans Grafana :
- Logs du frontend (nginx access logs)
- Logs de l'API (Laravel logs : requêtes, erreurs, SQL queries)
- Logs de l'indexer (Node.JS logs)
- Logs du reporting (Go job execution logs)
- Logs des bases de données (MySQL slow queries, RabbitMQ events)

---

## Phase 15 — Scripts de démonstration {#phase-15}

### 15.1 — `scripts/deploy-all.sh` — Déploiement complet

Ce script déploie **toute la stack** depuis zéro sur un cluster frais :

```
Étapes du script :
1. kubectl apply -f k8s/namespaces/
2. kubectl apply -f k8s/secrets/ (ou les générer à la volée)
3. kubectl apply -f k8s/rbac/
4. helm repo add bitnami https://charts.bitnami.com/bitnami
5. helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
6. helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
7. helm repo add grafana https://grafana.github.io/helm-charts
8. helm repo update
9. helm install mysql bitnami/mysql -n databases -f helm-values/mysql-values.yaml
10. helm install rabbitmq bitnami/rabbitmq -n databases -f helm-values/rabbitmq-values.yaml
11. helm install elasticsearch bitnami/elasticsearch -n databases -f helm-values/elasticsearch-values.yaml
12. helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx -f helm-values/ingress-nginx-values.yaml
13. helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f helm-values/kube-prometheus-stack-values.yaml
14. helm install loki-stack grafana/loki-stack -n logging -f helm-values/loki-stack-values.yaml
15. helm install frontend ./charts/frontend -n app
16. helm install api ./charts/api -n app
17. helm install indexer ./charts/indexer -n app
18. helm install reporting ./charts/reporting -n app
```

### 15.2 — `scripts/load-test.sh` — Démonstration de l'autoscaling

Ce script génère du trafic massif pour déclencher l'autoscaling des pods :

```
Étapes :
1. Récupérer l'URL de l'application (IP du LoadBalancer)
2. Lancer plusieurs boucles curl en parallèle vers /api et /
   (ou utiliser un outil comme `hey` ou `k6`)
3. Dans un autre terminal, surveiller : kubectl get hpa -n app -w
4. Observer le nombre de replicas augmenter automatiquement
```

### 15.3 — `scripts/zero-downtime-demo.sh` — Rolling update sans coupure

Ce script démontre un déploiement sans interruption de service :

```
Étapes :
1. Lancer une boucle de requêtes en continu vers l'API (compteur de succès/echecs)
2. Pendant ce temps, mettre à jour le tag de l'image de l'API vers une nouvelle version :
   helm upgrade api ./charts/api -n app --set image.tag=v2.0.0
3. Observer que AUCUNE requête n'échoue pendant le rolling update
4. Vérifier dans kubectl get pods -n app que les pods se remplacent un par un
```

### 15.4 — `scripts/rollback-demo.sh` — Déploiement cassé & rollback automatique

Ce script démontre un déploiement d'une image défectueuse avec rollback :

```
Étapes :
1. Déployer une image avec une readinessProbe qui échoue (image cassée) :
   helm upgrade api ./charts/api -n app --set image.tag=broken
2. Observer que le rolling update se bloque :
   kubectl rollout status deployment/api-deployment -n app
3. Les anciens pods restent en place (le service n'est PAS interrompu)
4. Le déploiement reste bloqué jusqu'au timeout
5. Exécuter le rollback :
   kubectl rollout undo deployment/api-deployment -n app
   ou : helm rollback api -n app
6. Observer le retour à l'état précédent
```

---

## Phase 16 — Bonus {#phase-16}

> Tous les fichiers bonus doivent être dans le répertoire `bonus/` comme stipulé dans le sujet.

### 16.1 — (Bonus) Let's Encrypt avec cert-manager

- Installer cert-manager via Helm : `jetstack/cert-manager`
- Créer un `ClusterIssuer` pointant vers l'ACME Let's Encrypt
- Ajouter l'annotation `cert-manager.io/cluster-issuer` sur l'Ingress
- L'Ingress obtiendra automatiquement un certificat TLS valide
- Rediriger tout le HTTP vers HTTPS dans les annotations de l'Ingress
- Fichiers : `bonus/cert-manager/cluster-issuer.yaml`, `bonus/cert-manager/ingress-tls.yaml`

### 16.2 — (Bonus) Environnement staging avec Kustomize

Créer une structure Kustomize :
- `bonus/kustomize/base/` : contient les manifests de base communs
- `bonus/kustomize/overlays/staging/kustomization.yaml` : override pour staging
  - Changer le namespace en `staging`
  - Réduire les replicas à 1
  - Utiliser des tags d'images `staging` au lieu de `latest`
  - Réduire les resource limits
  - Ajouter un label `environment: staging`

Déploiement de l'overlay staging :
```
kubectl apply -k bonus/kustomize/overlays/staging/
```

### 16.3 — (Bonus) cAdvisor

- cAdvisor expose des métriques détaillées sur la consommation des containers
- Déployer via Helm ou DaemonSet custom : `bonus/cadvisor/daemonset.yaml`
- Configurer un ServiceMonitor Prometheus pour scraper les métriques de cAdvisor
- Ajouter un dashboard Grafana dédié

### 16.4 — (Bonus) Istio Service Mesh

- Installer Istio via `istioctl install` ou Helm
- Activer l'injection automatique des sidecars dans le namespace `app`
- Configurer des `VirtualService` et `DestinationRule` pour le routing avancé
- Activer mTLS entre tous les services (chiffrement interne)
- Utiliser Kiali (dashboard Istio) pour visualiser le mesh
- Fichiers dans `bonus/istio/`

### 16.5 — (Bonus) CI/CD avec GitHub Actions

Créer le workflow `bonus/ci/.github/workflows/ci-cd.yaml` :

```
Pipeline :
1. Trigger : push sur main ou PR
2. Job "build-and-push" :
   a. Checkout du code
   b. Login sur ghcr.io avec le PAT stocké en secret GitHub
   c. Build des 4 images Docker (frontend, api, indexer, reporting)
   d. Tag avec le SHA du commit
   e. Push sur ghcr.io
3. Job "helm-lint" (after build) :
   a. Lint de tous les charts custom : helm lint ./charts/frontend etc.
   b. Dry-run de l'install : helm install --dry-run
4. Job "deploy-staging" (after helm-lint, sur push main uniquement) :
   a. Configurer kubectl avec le kubeconfig du cluster staging
   b. Déployer via helm upgrade --install avec le nouveau tag d'image
```

---

## Phase 17 — Documentation & Livraison {#phase-17}

### 17.1 — README.md principal

Le README doit contenir :
1. **Présentation** : description du projet, architecture en schéma ASCII ou image
2. **Prérequis** : outils à installer (kubectl, helm, docker)
3. **Configuration initiale** : comment configurer kubectl, créer le registre, pousser les images
4. **Déploiement** : commande unique `./scripts/deploy-all.sh` avec explication de chaque étape
5. **Accès aux services** : URLs de Grafana, de l'app, comment récupérer les mots de passe
6. **RBAC** : comment utiliser les kubeconfigs sysadmin et developer
7. **Démonstrations** : comment lancer chaque script de démo
8. **Rollback** : comment rollback un déploiement
9. **Bonus** : comment activer chaque bonus
10. **Auteurs** et contact

### 17.2 — Documentation des charts Helm

Dans chaque chart (`charts/<service>/README.md`) :
- Liste et description de tous les paramètres du `values.yaml`
- Exemples d'override
- Dépendances (secrets attendus)

### 17.3 — Checklist de validation avant soutenance

Vérifier chaque point du sujet :

**Fonctionnel :**
- [ ] Frontend accessible et fonctionnel
- [ ] CRUD produits via l'API
- [ ] Recherche de produits (via Elasticsearch)
- [ ] Indexation automatique lors de la création/suppression
- [ ] CronJob reporting testé manuellement (`kubectl create job --from=cronjob/reporting test-job -n app`)
- [ ] Message Teams reçu lors du job de reporting

**Infrastructure :**
- [ ] Helm chart custom pour chaque microservice
- [ ] Helm chart public pour MySQL, RabbitMQ, Elasticsearch, ingress-nginx, prometheus-stack, loki-stack
- [ ] Ingress NGINX comme point d'entrée unique
- [ ] Images Docker sur ghcr.io (registre privé)

**Sécurité :**
- [ ] Resource requests et limits sur tous les pods
- [ ] Tous les mots de passe dans des Secrets K8s
- [ ] Aucun secret en clair dans les fichiers Git
- [ ] Role `sysadmin` créé et fonctionnel
- [ ] Role `developer` créé avec permissions limitées
- [ ] Démonstration des droits différenciés (sysadmin peut tout, developer ne peut pas accéder aux secrets)
- [ ] Labels cohérents sur toutes les ressources

**Haute Disponibilité :**
- [ ] Au moins 2 replicas pour frontend et API
- [ ] HPA configuré et testé
- [ ] PDB configuré
- [ ] Anti-affinité configurée
- [ ] Rolling update zero-downtime démontré
- [ ] Déploiement cassé + rollback démontré
- [ ] Tolérance panne noeud : tuer un noeud et vérifier que l'app reste disponible

**Monitoring & Logs :**
- [ ] Prometheus collecte les métriques K8s
- [ ] Grafana accessible avec dashboards
- [ ] Logs disponibles dans Grafana via Loki

**Livraison :**
- [ ] Dépôt Git propre (pas de binaires, pas de secrets)
- [ ] Professeur invité sur le dépôt
- [ ] README complet et à jour

### 17.4 — Ordre de déploiement pour la soutenance

1. Provisionner le cluster cloud (avant la présentation)
2. Créer les namespaces
3. Créer les secrets
4. Configurer le RBAC
5. Déployer les composants d'infrastructure (Helm publics)
6. Attendre que MySQL, RabbitMQ, Elasticsearch soient `Running`
7. Déployer les microservices (Helm custom)
8. Attendre que tous les pods soient `Running` et `Ready`
9. Vérifier l'accès à l'application via le LoadBalancer
10. Démontrer les fonctionnalités (CRUD, search)
11. Démontrer l'autoscaling (load test)
12. Démontrer le rolling update zero-downtime
13. Démontrer le rollback
14. Montrer Grafana et Loki
15. Démontrer les rôles RBAC

---

## Récapitulatif des commandes kubectl/helm pour la soutenance

```bash
# 1. Namespaces
kubectl apply -f k8s/namespaces/

# 2. Secrets
kubectl apply -f k8s/secrets/

# 3. RBAC
kubectl apply -f k8s/rbac/

# 4. Repos Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 5. Infrastructure (Helm publics)
helm install mysql bitnami/mysql -n databases -f helm-values/mysql-values.yaml
helm install rabbitmq bitnami/rabbitmq -n databases -f helm-values/rabbitmq-values.yaml
helm install elasticsearch bitnami/elasticsearch -n databases -f helm-values/elasticsearch-values.yaml
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx -f helm-values/ingress-nginx-values.yaml
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f helm-values/kube-prometheus-stack-values.yaml
helm install loki-stack grafana/loki-stack -n logging -f helm-values/loki-stack-values.yaml

# 6. Microservices (Helm custom)
helm install frontend ./charts/frontend -n app
helm install api ./charts/api -n app
helm install indexer ./charts/indexer -n app
helm install reporting ./charts/reporting -n app
```

