# KubiQuest - A to Z

## Slide 1 - Platform Overview

- Monorepo split into `1. App`, `2. Kube`, `3. Docs`
- App stack: Angular, Laravel, Node.js, Go
- Platform stack: Kubernetes + Helm + Prometheus + Loki

## Slide 2 - Application Runtime

- Frontend calls API for CRUD and search
- API writes MySQL and publishes RabbitMQ events
- Indexer consumes queue and syncs Elasticsearch
- Reporting CronJob posts daily summary to MS Teams

## Slide 3 - Kubernetes Architecture

- Namespaces: `app`, `databases`, `monitoring`, `logging`, `ingress-nginx`
- Infra via public Helm charts
- App via custom Helm charts (`api`, `frontend`, `indexer`, `reporting`)
- RBAC, ResourceQuota, LimitRange, HPA, PDB enabled

## Slide 4 - Operations and Reliability

- End-to-end deployment script: `deploy-all.sh`
- Demo scripts: load test, zero downtime update, rollback
- Metrics and logs available in Grafana
- Recovery: Helm rollback and rollout undo

## Slide 5 - Key Commands

```bash
./2.\ Kube/scripts/build-and-push.sh
./2.\ Kube/scripts/deploy-all.sh
./2.\ Kube/scripts/load-test.sh http://<EXTERNAL_IP> 120
./2.\ Kube/scripts/zero-downtime-demo.sh http://<EXTERNAL_IP> v2.0.0
./2.\ Kube/scripts/rollback-demo.sh http://<EXTERNAL_IP>
```

## Slide 6 - Closing

- Architecture supports scale, observability, and controlled rollback.
- Documentation is available in Markdown and HTML under `3. Docs`.
