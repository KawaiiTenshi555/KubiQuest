# Helm Chart — api

Déploie l'API Laravel (PHP 8.2 + nginx + php-fpm) de KubiQuest dans Kubernetes.
Inclut un `initContainer` qui exécute les migrations MySQL avant le démarrage.

## Secrets requis

Les secrets suivants doivent exister dans le namespace **avant** l'installation :

| Secret K8s | Clés utilisées |
|------------|---------------|
| `mysql-secret` | `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` |
| `rabbitmq-secret` | `RABBITMQ_USER`, `RABBITMQ_PASSWORD` |
| `elasticsearch-secret` | `ELASTICSEARCH_USERNAME`, `ELASTICSEARCH_PASSWORD` |
| `api-secret` | `APP_KEY` |
| `registry-secret` | imagePullSecret pour ghcr.io |

## Paramètres

| Paramètre | Description | Défaut |
|-----------|-------------|--------|
| `replicaCount` | Nombre de pods initiaux | `2` |
| `image.repository` | Image Docker | `ghcr.io/kubiquest/api` |
| `image.tag` | Tag de l'image | `latest` |
| `image.pullPolicy` | Politique de pull | `Always` |
| `imagePullSecrets` | Secrets pour le pull d'image | `[{name: registry-secret}]` |
| `environment` | Valeur du label `environment` | `production` |
| `service.type` | Type de Service | `ClusterIP` |
| `service.port` | Port exposé | `80` |
| `env.APP_ENV` | Environnement Laravel | `production` |
| `env.APP_DEBUG` | Mode debug Laravel | `"false"` |
| `env.DB_HOST` | Hôte MySQL | `mysql.databases.svc.cluster.local` |
| `env.DB_PORT` | Port MySQL | `"3306"` |
| `env.RABBITMQ_HOST` | Hôte RabbitMQ | `rabbitmq.databases.svc.cluster.local` |
| `env.RABBITMQ_EXCHANGE` | Exchange RabbitMQ | `products` |
| `env.ELASTICSEARCH_HOST` | Hôte Elasticsearch | `elasticsearch.databases.svc.cluster.local` |
| `existingSecrets` | Liste des secrets injectés via `envFrom` | `[mysql-secret, rabbitmq-secret, elasticsearch-secret, api-secret]` |
| `initContainers.migrations.enabled` | Exécuter `php artisan migrate --force` au démarrage | `true` |
| `resources.requests.memory` | Mémoire demandée | `256Mi` |
| `resources.requests.cpu` | CPU demandé | `250m` |
| `resources.limits.memory` | Limite mémoire | `512Mi` |
| `resources.limits.cpu` | Limite CPU | `500m` |
| `autoscaling.enabled` | Activer le HPA | `true` |
| `autoscaling.minReplicas` | Replicas minimum | `2` |
| `autoscaling.maxReplicas` | Replicas maximum | `6` |
| `autoscaling.targetCPUUtilizationPercentage` | Seuil CPU scale-up | `70` |
| `autoscaling.targetMemoryUtilizationPercentage` | Seuil mémoire scale-up | `80` |
| `podDisruptionBudget.enabled` | Activer le PDB | `true` |
| `podDisruptionBudget.minAvailable` | Pods minimum disponibles | `1` |
| `serviceMonitor.enabled` | Créer un ServiceMonitor Prometheus | `true` |
| `serviceMonitor.interval` | Intervalle de scrape | `30s` |
| `serviceMonitor.scrapeTimeout` | Timeout du scrape | `10s` |
| `livenessProbe` | Liveness probe | `GET /api/health port 80, delay 60s` |
| `readinessProbe` | Readiness probe | `GET /api/health port 80, delay 20s` |

## Endpoints exposés

| Endpoint | Description |
|----------|-------------|
| `GET /api/health` | Statut de tous les services (MySQL, ES, RabbitMQ) |
| `GET /api/metrics` | Métriques Prometheus (produits, mysql_up, api_info) |
| `GET /api/products` | Liste des produits |
| `POST /api/products` | Créer un produit |
| `DELETE /api/products/{id}` | Supprimer un produit |
| `GET /api/search?q=…` | Recherche Elasticsearch |

## Installation

```bash
helm install api ./2.\ Kube/charts/api -n app
```

## Override pour staging

```bash
helm install api ./2.\ Kube/charts/api -n staging \
  --set replicaCount=1 \
  --set resources.requests.memory=128Mi \
  --set resources.limits.memory=256Mi \
  --set autoscaling.minReplicas=1 \
  --set autoscaling.maxReplicas=2 \
  --set serviceMonitor.enabled=false
```
