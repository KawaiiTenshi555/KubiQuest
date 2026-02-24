# Chapter 01 - Application Layer (1. App)

## 1. Goal

The application layer provides a simple e-commerce style workflow:

- create products
- list products
- delete products
- search products
- expose health and metrics
- send daily report to MS Teams

## 2. Services

### 2.1 Frontend (Angular)

Path: `1. App/frontend`

Main responsibilities:

- render product list
- create/delete products via API
- run search queries
- poll health endpoint every 30 seconds

### 2.2 API (Laravel)

Path: `1. App/api`

Main endpoints:

- `GET /api/health`
- `GET /api/metrics`
- `GET /api/products`
- `POST /api/products`
- `DELETE /api/products/{id}`
- `GET /api/search?q=...`

Main responsibilities:

- persist products in MySQL
- publish product events to RabbitMQ
- query Elasticsearch for full-text search
- expose operational metrics

### 2.3 Indexer (Node.js)

Path: `1. App/indexer`

Main responsibilities:

- consume RabbitMQ messages from `products-indexer`
- upsert/delete documents in Elasticsearch
- expose `/health` and `/metrics`

Recent refactor applied:

- explicit `ELASTICSEARCH_SCHEME` support (`http`/`https`)
- safer vhost URL encoding for RabbitMQ
- cleaner logs and shutdown handling

### 2.4 Reporting (Go)

Path: `1. App/reporting`

Main responsibilities:

- connect to MySQL
- compute `COUNT(*)` on products
- send MessageCard to MS Teams webhook

Recent refactor applied:

- clearer function split (`countProducts`, `buildTeamsPayload`, `postTeams`)
- explicit DB pool settings
- simpler error flow

## 3. Runtime Data Flow

1. User calls frontend.
2. Frontend calls API.
3. API writes product state in MySQL.
4. API publishes event to RabbitMQ fanout exchange.
5. Indexer consumes and updates Elasticsearch.
6. Search endpoint returns Elasticsearch results.
7. Cron reporting reads MySQL and posts to Teams.

## 4. Build and Packaging

Path: `1. App/docker`

Dockerfiles were updated to support the new repository layout with spaces:

- `1. App/docker/frontend/Dockerfile`
- `1. App/docker/api/Dockerfile`
- `1. App/docker/indexer/Dockerfile`
- `1. App/docker/reporting/Dockerfile`

Build context remains repository root.

## 5. Local Development

### 5.1 Start infra dependencies

```bash
docker compose -f "1. App/docker-compose.dev.yml" up -d
```

This starts:

- MySQL
- RabbitMQ
- Elasticsearch

### 5.2 Build and run a service manually

Examples:

```bash
docker build -f "1. App/docker/api/Dockerfile" -t kubiquest-api:dev .
docker run --rm -p 8080:80 kubiquest-api:dev
```

## 6. Operational Health

- API health: `GET /api/health`
- API metrics: `GET /api/metrics`
- Indexer health: `GET /health`
- Indexer metrics: `GET /metrics`

## 7. Common App Troubleshooting

1. MySQL unreachable:
- check DB secret values and service DNS.

2. RabbitMQ queue not consumed:
- check indexer logs and queue bindings.

3. Search empty after create:
- check API publish logs and indexer message processing.

4. Teams report not sent:
- verify `MSTEAMS_WEBHOOK_URL` secret and outbound network.
