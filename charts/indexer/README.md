# Helm Chart — indexer

Déploie le consommateur RabbitMQ → Elasticsearch (Node.JS) de KubiQuest.
Tourne en continu et indexe/supprime les produits dans Elasticsearch en réponse
aux messages de l'exchange fanout `products`.

## Secrets requis

| Secret K8s | Clés utilisées |
|------------|---------------|
| `rabbitmq-secret` | `RABBITMQ_USER`, `RABBITMQ_PASSWORD` |
| `elasticsearch-secret` | `ELASTICSEARCH_USERNAME`, `ELASTICSEARCH_PASSWORD` |
| `registry-secret` | imagePullSecret pour ghcr.io |

## Paramètres

| Paramètre | Description | Défaut |
|-----------|-------------|--------|
| `replicaCount` | Nombre de pods initiaux | `1` |
| `image.repository` | Image Docker | `ghcr.io/kubiquest/indexer` |
| `image.tag` | Tag de l'image | `latest` |
| `image.pullPolicy` | Politique de pull | `Always` |
| `imagePullSecrets` | Secrets pour le pull d'image | `[{name: registry-secret}]` |
| `service.enabled` | Créer un Service K8s (port 3000) | `true` |
| `service.type` | Type de Service | `ClusterIP` |
| `service.port` | Port exposé | `3000` |
| `env.RABBITMQ_HOST` | Hôte RabbitMQ | `rabbitmq.databases.svc.cluster.local` |
| `env.RABBITMQ_QUEUE` | Queue à consommer | `products-indexer` |
| `env.RABBITMQ_EXCHANGE` | Exchange fanout | `products` |
| `env.ELASTICSEARCH_HOST` | Hôte Elasticsearch | `elasticsearch.databases.svc.cluster.local` |
| `env.ELASTICSEARCH_INDEX` | Index Elasticsearch | `products` |
| `existingSecrets` | Secrets injectés via `envFrom` | `[rabbitmq-secret, elasticsearch-secret]` |
| `resources.requests.memory` | Mémoire demandée | `128Mi` |
| `resources.requests.cpu` | CPU demandé | `100m` |
| `resources.limits.memory` | Limite mémoire | `256Mi` |
| `resources.limits.cpu` | Limite CPU | `300m` |
| `autoscaling.enabled` | Activer le HPA | `true` |
| `autoscaling.minReplicas` | Replicas minimum | `1` |
| `autoscaling.maxReplicas` | Replicas maximum | `3` |
| `podDisruptionBudget.enabled` | Activer le PDB | `true` |
| `podDisruptionBudget.minAvailable` | Pods minimum disponibles | `0` (délai d'indexation acceptable) |
| `serviceMonitor.enabled` | Créer un ServiceMonitor Prometheus | `true` |
| `serviceMonitor.interval` | Intervalle de scrape | `30s` |
| `livenessProbe` | Liveness probe | `GET /health port 3000, delay 30s` |
| `readinessProbe` | Readiness probe | `GET /health port 3000, delay 10s` |

## Endpoints exposés (port 3000)

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Statut Elasticsearch + RabbitMQ (JSON, 200/503) |
| `GET /metrics` | Métriques Prometheus (messages traités, ES up, RMQ up, Node.js) |

## Installation

```bash
helm install indexer ./charts/indexer -n app
```

## Override pour staging

```bash
helm install indexer ./charts/indexer -n staging \
  --set replicaCount=1 \
  --set resources.requests.memory=64Mi \
  --set resources.limits.memory=128Mi \
  --set autoscaling.enabled=false \
  --set serviceMonitor.enabled=false
```
