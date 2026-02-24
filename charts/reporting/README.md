# Helm Chart — reporting

Déploie le job de reporting quotidien (Go) de KubiQuest comme `CronJob` Kubernetes.
S'exécute à **minuit (00:00 UTC)**, compte les produits dans MySQL et envoie
le résultat via webhook Microsoft Teams.

## Secrets requis

| Secret K8s | Clés utilisées |
|------------|---------------|
| `mysql-secret` | `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DATABASE` |
| `msteams-secret` | `MSTEAMS_WEBHOOK_URL` |
| `registry-secret` | imagePullSecret pour ghcr.io |

## Paramètres

| Paramètre | Description | Défaut |
|-----------|-------------|--------|
| `image.repository` | Image Docker | `ghcr.io/kubiquest/reporting` |
| `image.tag` | Tag de l'image | `latest` |
| `image.pullPolicy` | Politique de pull | `Always` |
| `imagePullSecrets` | Secrets pour le pull d'image | `[{name: registry-secret}]` |
| `schedule` | Expression cron d'exécution | `"0 0 * * *"` (minuit UTC) |
| `concurrencyPolicy` | Politique de concurrence | `Forbid` (pas de 2 jobs simultanés) |
| `successfulJobsHistoryLimit` | Nombre de jobs réussis conservés | `3` |
| `failedJobsHistoryLimit` | Nombre de jobs échoués conservés | `1` |
| `existingSecrets` | Secrets injectés via `envFrom` | `[mysql-secret, msteams-secret]` |
| `env.DB_HOST` | Hôte MySQL | `mysql.databases.svc.cluster.local` |
| `env.DB_PORT` | Port MySQL | `"3306"` |
| `resources.requests.memory` | Mémoire demandée | `64Mi` |
| `resources.requests.cpu` | CPU demandé | `50m` |
| `resources.limits.memory` | Limite mémoire | `128Mi` |
| `resources.limits.cpu` | Limite CPU | `100m` |

## Installation

```bash
helm install reporting ./charts/reporting -n app
```

## Déclencher manuellement (test sans attendre minuit)

```bash
kubectl create job --from=cronjob/reporting-cronjob test-reporting-$(date +%s) -n app

# Voir les logs
kubectl logs -n app -l job-name=test-reporting-<timestamp> -f
```

## Modifier l'heure d'exécution

```bash
# Exécuter à 8h00 UTC au lieu de minuit
helm upgrade reporting ./charts/reporting -n app \
  --set schedule="0 8 * * *"
```

## Override pour staging (toutes les 5 minutes — pour tester)

```bash
helm install reporting ./charts/reporting -n staging \
  --set schedule="*/5 * * * *" \
  --set successfulJobsHistoryLimit=1
```

## Format du message Teams

Le job envoie un `MessageCard` au format MS Teams :

```json
{
  "@type": "MessageCard",
  "@context": "http://schema.org/extensions",
  "themeColor": "0076D7",
  "summary": "KubiQuest Daily Report",
  "sections": [{
    "activityTitle": "KubiQuest Daily Report",
    "facts": [
      { "name": "Products in database:", "value": "42" },
      { "name": "Report date:", "value": "2026-02-24 00:00 UTC" }
    ]
  }]
}
```
