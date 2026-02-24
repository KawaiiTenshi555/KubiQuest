# Helm Chart — frontend

Déploie le frontend Angular (SPA nginx) de KubiQuest dans Kubernetes.

## Secrets requis

Aucun secret Kubernetes requis (le frontend est une SPA statique, les appels API
passent par nginx proxy vers `api-service`).

Le secret `registry-secret` (imagePullSecret) doit exister dans le namespace.

## Paramètres

| Paramètre | Description | Défaut |
|-----------|-------------|--------|
| `replicaCount` | Nombre de pods initiaux | `2` |
| `image.repository` | Image Docker | `ghcr.io/kubiquest/frontend` |
| `image.tag` | Tag de l'image | `latest` |
| `image.pullPolicy` | Politique de pull | `Always` |
| `imagePullSecrets` | Secrets pour le pull d'image privée | `[{name: registry-secret}]` |
| `service.type` | Type de Service | `ClusterIP` |
| `service.port` | Port exposé | `80` |
| `resources.requests.memory` | Mémoire demandée | `64Mi` |
| `resources.requests.cpu` | CPU demandé | `50m` |
| `resources.limits.memory` | Limite mémoire | `128Mi` |
| `resources.limits.cpu` | Limite CPU | `200m` |
| `autoscaling.enabled` | Activer le HPA | `true` |
| `autoscaling.minReplicas` | Replicas minimum (HPA) | `2` |
| `autoscaling.maxReplicas` | Replicas maximum (HPA) | `5` |
| `autoscaling.targetCPUUtilizationPercentage` | Seuil CPU pour scale-up | `70` |
| `autoscaling.targetMemoryUtilizationPercentage` | Seuil mémoire pour scale-up | `80` |
| `podDisruptionBudget.enabled` | Activer le PDB | `true` |
| `podDisruptionBudget.minAvailable` | Pods minimum disponibles | `1` |
| `livenessProbe` | Configuration liveness probe | `GET / port 80` |
| `readinessProbe` | Configuration readiness probe | `GET / port 80` |
| `nodeSelector` | Sélecteur de noeud | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinité de pod | `{}` |

> La **topologySpreadConstraint** (étalement sur les noeuds) est hardcodée dans le template pour garantir la HA.

## Installation

```bash
helm install frontend ./2.\ Kube/charts/frontend -n app
```

## Upgrade avec un nouveau tag d'image

```bash
helm upgrade frontend ./2.\ Kube/charts/frontend -n app \
  --set image.tag=v2.0.0 \
  --wait
```

## Override des resources pour staging

```bash
helm install frontend ./2.\ Kube/charts/frontend -n staging \
  --set replicaCount=1 \
  --set resources.requests.memory=32Mi \
  --set resources.limits.memory=64Mi \
  --set autoscaling.minReplicas=1 \
  --set autoscaling.maxReplicas=2
```
