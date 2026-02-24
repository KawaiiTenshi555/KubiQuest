# Plan de Réalisation — Applications KubiQuest
> Détail technique de chaque microservice à coder

---

## Table des matières

1. [Vue d'ensemble & contrats entre services](#vue-densemble)
2. [App 1 — API Laravel (PHP)](#app-1-api-laravel)
3. [App 2 — Frontend Angular](#app-2-frontend-angular)
4. [App 3 — Indexer Node.JS](#app-3-indexer-nodejs)
5. [App 4 — Reporting Job (Go)](#app-4-reporting-go)
6. [Ordre de développement recommandé](#ordre)

---

## Vue d'ensemble & contrats entre services {#vue-densemble}

### Schéma des interactions

```
[Browser]
    │
    │  HTTP
    ▼
[Angular Frontend]
    │
    │  HTTP REST → /api/*
    ▼
[Laravel API]  ──── MySQL (CRUD produits)
    │          ──── Elasticsearch (recherche)
    │          ──── RabbitMQ exchange "products" (publish)
    │
    │  (async, via RabbitMQ)
    ▼
[Node.JS Indexer]  ──── RabbitMQ queue "products-indexer" (consume)
                   ──── Elasticsearch (index/delete documents)

[Go Reporting CronJob]  ──── MySQL (COUNT produits)
                        ──── MS Teams webhook (HTTP POST)
```

### Schéma de la base MySQL

```sql
CREATE TABLE products (
    id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name       VARCHAR(255) NOT NULL,
    image      VARCHAR(512) NOT NULL,  -- URL de l'image
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### Format des messages RabbitMQ

```json
// Création de produit
{
  "action": "created",
  "product": {
    "id": 42,
    "name": "Shadow",
    "image": "https://example.com/shadow.jpg"
  }
}

// Suppression de produit
{
  "action": "deleted",
  "product": {
    "id": 42,
    "name": "Shadow",
    "image": "https://example.com/shadow.jpg"
  }
}
```

### Index Elasticsearch

```json
// Index: "products"
// Document:
{
  "id": 42,
  "name": "Shadow",
  "image": "https://example.com/shadow.jpg"
}
```

### Réponse de l'endpoint `/api/health`

```json
{
  "hostname": "api-deployment-abc123-xyz",
  "mysql": "healthy",
  "products": 32,
  "mysql_migrations": "healthy",
  "elasticsearch": "healthy",
  "msgs": 2,
  "response_time_ms": 99
}
```

---

## App 1 — API Laravel (PHP) {#app-1-api-laravel}

### Rôle

Backend REST. Point central de l'application : gère les produits en MySQL, publie les changements dans RabbitMQ, et proxy les recherches vers Elasticsearch.

### Structure des fichiers

```
api/
├── app/
│   ├── Http/
│   │   ├── Controllers/
│   │   │   ├── HealthController.php
│   │   │   ├── ProductController.php
│   │   │   └── SearchController.php
│   │   └── Resources/
│   │       └── ProductResource.php
│   ├── Models/
│   │   └── Product.php
│   └── Services/
│       ├── ElasticsearchService.php
│       └── RabbitMQService.php
├── database/
│   └── migrations/
│       └── 2024_01_01_000000_create_products_table.php
├── routes/
│   └── api.php
├── config/
│   ├── elasticsearch.php   (config custom)
│   └── rabbitmq.php        (config custom)
├── composer.json
└── .env.example
```

### Dépendances Composer

```json
{
  "require": {
    "php": "^8.2",
    "laravel/framework": "^11.0",
    "elasticsearch/elasticsearch": "^8.0",
    "php-amqplib/php-amqplib": "^3.5"
  }
}
```

### Variables d'environnement attendues

```ini
APP_NAME=KubiQuest
APP_ENV=production
APP_KEY=base64:...
APP_DEBUG=false
LOG_CHANNEL=stderr

DB_CONNECTION=mysql
DB_HOST=mysql.databases.svc.cluster.local
DB_PORT=3306
DB_DATABASE=kubiquest
DB_USERNAME=kubiuser
DB_PASSWORD=...

ELASTICSEARCH_HOST=elasticsearch.databases.svc.cluster.local
ELASTICSEARCH_PORT=9200
ELASTICSEARCH_USERNAME=elastic
ELASTICSEARCH_PASSWORD=...
ELASTICSEARCH_INDEX=products

RABBITMQ_HOST=rabbitmq.databases.svc.cluster.local
RABBITMQ_PORT=5672
RABBITMQ_USER=kubiuser
RABBITMQ_PASSWORD=...
RABBITMQ_VHOST=/
RABBITMQ_EXCHANGE=products
```

### Endpoints REST

| Méthode | URI                  | Controller              | Description                                  |
|---------|----------------------|-------------------------|----------------------------------------------|
| GET     | `/api/health`        | HealthController@index  | Statut de santé de tous les services         |
| GET     | `/api/products`      | ProductController@index | Liste tous les produits depuis MySQL          |
| POST    | `/api/products`      | ProductController@store | Crée un produit (MySQL + RabbitMQ)           |
| DELETE  | `/api/products/{id}` | ProductController@destroy| Supprime un produit (MySQL + RabbitMQ)       |
| GET     | `/api/search`        | SearchController@index  | Recherche Elasticsearch (`?q=keyword`)       |

### Détail de chaque controller

#### `HealthController@index` — GET /api/health

```
Actions:
1. Récupérer le hostname du pod (env("HOSTNAME") ou gethostname())
2. Tenter une connexion MySQL → statut "healthy" ou "error"
3. Compter le nombre de lignes dans la table "products" (DB::table('products')->count())
4. Vérifier que les migrations ont été appliquées (table "migrations" existe → "healthy")
5. Tenter une requête Elasticsearch ping → "healthy" ou "error"
6. Compter les messages dans la queue RabbitMQ via management API → int
7. Mesurer le temps de réponse total (microtime)

Retourner JSON:
{
  "hostname": string,
  "mysql": "healthy"|"error",
  "products": int,
  "mysql_migrations": "healthy"|"error",
  "elasticsearch": "healthy"|"error",
  "msgs": int,
  "response_time_ms": int
}
```

#### `ProductController@index` — GET /api/products

```
Actions:
1. Récupérer tous les produits: Product::all() ou Product::latest()->get()
2. Retourner JSON: tableau de { "id", "name", "image", "created_at" }
```

#### `ProductController@store` — POST /api/products

```
Validation du body:
- "name": required, string, max:255
- "image": required, string (URL), max:512

Actions:
1. Créer le produit en MySQL: $product = Product::create(request->validated())
2. Publier dans RabbitMQ:
   - Exchange: config('rabbitmq.exchange') = "products"
   - Routing key: ""
   - Body JSON: { "action": "created", "product": { id, name, image } }
3. Retourner le produit créé (HTTP 201)
```

#### `ProductController@destroy` — DELETE /api/products/{id}

```
Actions:
1. Trouver le produit: Product::findOrFail($id)
2. Sauvegarder les données avant suppression
3. Supprimer le produit: $product->delete()
4. Publier dans RabbitMQ:
   - Body JSON: { "action": "deleted", "product": { id, name, image } }
5. Retourner HTTP 204
```

#### `SearchController@index` — GET /api/search?q=keyword

```
Paramètres:
- "q": required, string

Actions:
1. Construire la requête Elasticsearch:
   {
     "query": {
       "match": {
         "name": { "query": "keyword", "fuzziness": "AUTO" }
       }
     }
   }
2. Exécuter la requête sur l'index "products"
3. Mapper les hits en tableau de produits: { id, name, image }
4. Retourner JSON
```

### Services internes

#### `RabbitMQService`

```
Méthodes:
- __construct(): Connexion AMQP avec AMQPStreamConnection
- publish(string $action, array $product): void
  → Créer le channel
  → Déclarer l'exchange "products" de type "fanout"
  → Publier AMQPMessage(json_encode({action, product}))
  → Fermer le channel
```

#### `ElasticsearchService`

```
Méthodes:
- __construct(): Instancier Client Elasticsearch avec host/auth depuis config
- search(string $query): array
  → Appeler $client->search() avec la query match
  → Retourner les hits mappés
- ping(): bool
  → Appeler $client->ping() → true/false
```

### Migration MySQL

```php
// database/migrations/..._create_products_table.php
Schema::create('products', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->string('image', 512);
    $table->timestamps();
});
```

### Model Eloquent

```php
// app/Models/Product.php
class Product extends Model {
    protected $fillable = ['name', 'image'];
}
```

### Routes

```php
// routes/api.php
Route::get('/health', [HealthController::class, 'index']);
Route::apiResource('/products', ProductController::class)->only(['index', 'store', 'destroy']);
Route::get('/search', [SearchController::class, 'index']);
```

### CORS

Activer CORS pour laisser le frontend (servi par nginx) appeler l'API :
- Configurer `config/cors.php` : `'allowed_origins' => ['*']`

---

## App 2 — Frontend Angular {#app-2-frontend-angular}

### Rôle

Application SPA Angular. Affiche la liste des produits, permet d'en créer et d'en supprimer, et offre une barre de recherche (via Elasticsearch proxied par l'API).

### Structure des fichiers

```
frontend/
├── src/
│   ├── app/
│   │   ├── app.component.ts          # Composant racine
│   │   ├── app.component.html
│   │   ├── app.component.scss
│   │   ├── app.config.ts             # Configuration Angular (standalone)
│   │   ├── app.routes.ts
│   │   │
│   │   ├── models/
│   │   │   ├── product.model.ts      # interface Product
│   │   │   └── health.model.ts       # interface Health
│   │   │
│   │   ├── services/
│   │   │   └── api.service.ts        # Tous les appels HTTP
│   │   │
│   │   └── components/
│   │       ├── health/
│   │       │   ├── health.component.ts
│   │       │   ├── health.component.html
│   │       │   └── health.component.scss
│   │       ├── product-list/
│   │       │   ├── product-list.component.ts
│   │       │   ├── product-list.component.html
│   │       │   └── product-list.component.scss
│   │       ├── product-card/
│   │       │   ├── product-card.component.ts
│   │       │   ├── product-card.component.html
│   │       │   └── product-card.component.scss
│   │       └── add-product/
│   │           ├── add-product.component.ts
│   │           ├── add-product.component.html
│   │           └── add-product.component.scss
│   │
│   ├── environments/
│   │   ├── environment.ts            # { apiUrl: '/api' }  (via proxy nginx)
│   │   └── environment.prod.ts
│   │
│   └── styles.scss                   # Styles globaux
│
├── angular.json
├── package.json
└── tsconfig.json
```

### Dépendances npm

```json
{
  "dependencies": {
    "@angular/core": "^17.0.0",
    "@angular/common": "^17.0.0",
    "@angular/forms": "^17.0.0",
    "@angular/platform-browser": "^17.0.0",
    "@angular/router": "^17.0.0",
    "rxjs": "^7.8.0"
  },
  "devDependencies": {
    "@angular/cli": "^17.0.0",
    "@angular/compiler-cli": "^17.0.0",
    "typescript": "^5.2.0"
  }
}
```

### Modèles TypeScript

#### `product.model.ts`

```typescript
export interface Product {
  id: number;
  name: string;
  image: string;
  created_at?: string;
}
```

#### `health.model.ts`

```typescript
export interface Health {
  hostname: string;
  mysql: 'healthy' | 'error';
  products: number;
  mysql_migrations: 'healthy' | 'error';
  elasticsearch: 'healthy' | 'error';
  msgs: number;
  response_time_ms: number;
}
```

### `ApiService`

```typescript
// services/api.service.ts
// URL de base: environment.apiUrl = '/api'

// Méthodes:
getHealth(): Observable<Health>
  → GET /api/health

getProducts(): Observable<Product[]>
  → GET /api/products

createProduct(name: string, image: string): Observable<Product>
  → POST /api/products  body: { name, image }

deleteProduct(id: number): Observable<void>
  → DELETE /api/products/:id

searchProducts(query: string): Observable<Product[]>
  → GET /api/search?q=<query>
```

### Composants

#### `AppComponent`

```
Template layout:
┌─────────────────────────────────────────┐
│  KubiQuest            [titre de l'app]   │
├────────────────┬────────────────────────┤
│                │  Welcome               │
│  Health        │                        │
│  (widget JSON) │  [AddProductComponent] │
│                │                        │
│                │  Products              │
│                │  [Search bar]          │
│                │  [ProductListComponent]│
└────────────────┴────────────────────────┘

Responsabilités:
- Injecter ApiService
- Appeler getHealth() au chargement (interval 30s pour refresh)
- Passer les données de health au HealthComponent
- Passer la liste de produits au ProductListComponent
- Écouter les événements (productAdded, productDeleted, searchQuery)
  et mettre à jour la liste
```

#### `HealthComponent`

```
Input: health: Health | null

Template:
- Affiche un bloc JSON formaté (ou un tableau) avec:
  - hostname
  - mysql: badge vert "healthy" / rouge "error"
  - products: nombre
  - mysql_migrations: badge
  - elasticsearch: badge vert/rouge
  - msgs: nombre
  - response_time_ms: en ms

Comportement:
- Appelle getHealth() toutes les 30 secondes (interval RxJS)
- Si erreur: affiche "API unreachable"
```

#### `AddProductComponent`

```
Template — Formulaire avec:
- Champ "Name": input text (required, maxlength=255)
- Champ "Image URL": input text (required, URL validator)
- Bouton "Add Product" (disabled si formulaire invalide ou loading)

Comportement:
- Au submit: appeler ApiService.createProduct(name, image)
- Si succès: émettre Output() productAdded → rafraîchir la liste
- Si erreur: afficher un message d'erreur inline
- Reset le formulaire après succès
```

#### `ProductListComponent`

```
Input: products: Product[]

Template:
- Barre de recherche: input text avec événement (debounce 300ms)
  - Si vide: afficher tous les produits (getProducts)
  - Si texte: appeler searchProducts(query)
- Grille CSS (3 colonnes): itération sur products avec *ngFor
  → ProductCardComponent pour chaque produit

Comportement:
- Écoute les changements dans la barre de recherche (debounceTime 300ms via RxJS)
- Gère l'état "loading" pendant les requêtes
- Affiche "No products found" si la liste est vide
```

#### `ProductCardComponent`

```
Input: product: Product
Output: productDeleted: EventEmitter<number> (émet l'id)

Template:
┌──────────────────────┐
│   [image du produit] │  ← img src="{{ product.image }}"
│                      │     object-fit: cover, carré
│  [nom]  [btn ×]      │  ← nom en bas gauche, croix rouge en bas droite
└──────────────────────┘

Comportement:
- Clic sur la croix: appeler ApiService.deleteProduct(product.id)
- Si succès: émettre productDeleted avec l'id
- Gérer l'état loading (désactiver le bouton pendant la requête)
- Fallback image si l'URL est invalide (onerror → image placeholder)
```

### Routing

Application SPA mono-page, pas de routing nécessaire.
Toute l'UI tient dans `AppComponent`.

### Configuration Angular

```typescript
// app.config.ts — Angular 17 standalone
provideHttpClient(withFetch())
provideRouter(routes)
```

### Points importants

- **L'URL de l'API** est `/api` — nginx dans le Dockerfile fait proxy pass
  vers le service K8s `api-service`. Le frontend ne connaît pas l'adresse interne.
- Utiliser le **HttpClientModule** ou `provideHttpClient()` (Angular 17 standalone)
- Gérer les **erreurs HTTP** proprement (afficher un message user-friendly)
- Pas besoin d'authentification (app d'administration interne)

---

## App 3 — Indexer Node.JS {#app-3-indexer-nodejs}

### Rôle

Consommateur RabbitMQ → indexe les produits dans Elasticsearch.
Tourne en continu dans le cluster. Expose `/health` pour les probes K8s.

### Structure des fichiers

```
indexer/
├── src/
│   ├── index.js              # Point d'entrée: démarrage du serveur + consumer
│   ├── consumer.js           # Logique RabbitMQ consumer
│   ├── elasticsearch.js      # Client Elasticsearch + méthodes index/delete
│   └── health.js             # Serveur HTTP minimal pour /health
├── package.json
└── .env.example
```

### Dépendances npm

```json
{
  "dependencies": {
    "amqplib": "^0.10.3",
    "@elastic/elasticsearch": "^8.12.0"
  }
}
```

### Variables d'environnement attendues

```ini
RABBITMQ_HOST=rabbitmq.databases.svc.cluster.local
RABBITMQ_PORT=5672
RABBITMQ_USER=kubiuser
RABBITMQ_PASSWORD=...
RABBITMQ_VHOST=/
RABBITMQ_QUEUE=products-indexer
RABBITMQ_EXCHANGE=products

ELASTICSEARCH_HOST=elasticsearch.databases.svc.cluster.local
ELASTICSEARCH_PORT=9200
ELASTICSEARCH_USERNAME=elastic
ELASTICSEARCH_PASSWORD=...
ELASTICSEARCH_INDEX=products
```

### Fichier `src/index.js` — Point d'entrée

```
Actions au démarrage:
1. Démarrer le serveur HTTP de health check (port 3000)
2. Attendre la connexion Elasticsearch (retry avec backoff)
3. S'assurer que l'index "products" existe (createIndexIfNotExists)
4. Démarrer le consumer RabbitMQ (retry avec backoff sur connexion)
5. Logger "Indexer ready"

Gestion des erreurs:
- Sur déconnexion RabbitMQ: tenter reconnexion toutes les 5s
- Sur erreur fatale: logger et exit(1) (K8s redémarrera le pod)
```

### Fichier `src/consumer.js` — Consumer RabbitMQ

```
Connexion AMQP:
- amqp.connect(`amqp://${user}:${pass}@${host}:${port}/${vhost}`)
- Créer un channel
- Déclarer l'exchange "products" de type "fanout"
- Déclarer la queue "products-indexer" (durable: true)
- Binder la queue sur l'exchange
- Configurer prefetch(1) pour ne traiter qu'un message à la fois

Traitement des messages:
- Parser le JSON du message
- Si action === "created":
    → elasticsearch.indexProduct(product)
- Si action === "deleted":
    → elasticsearch.deleteProduct(product.id)
- Acquitter le message (channel.ack) après traitement réussi
- Sur erreur: nack le message (channel.nack, requeue: false) + logger l'erreur
```

### Fichier `src/elasticsearch.js` — Client Elasticsearch

```
Client: new Client({ node: `http://${host}:${port}`, auth: { username, password } })

Méthodes:

createIndexIfNotExists():
  → Vérifier si l'index existe: client.indices.exists({ index })
  → Si non: client.indices.create({
      index,
      mappings: {
        properties: {
          id:    { type: "integer" },
          name:  { type: "text" },
          image: { type: "keyword" }
        }
      }
    })

indexProduct(product):
  → client.index({
      index,
      id: String(product.id),
      document: { id: product.id, name: product.name, image: product.image }
    })

deleteProduct(id):
  → client.delete({ index, id: String(id) })
  → Ignorer l'erreur 404 (déjà supprimé)

ping():
  → client.ping() → boolean
```

### Fichier `src/health.js` — Health check HTTP

```
Serveur HTTP Node natif (http.createServer) sur port 3000:

GET /health:
  → Tenter un ping Elasticsearch
  → Répondre JSON:
    {
      "status": "ok",
      "elasticsearch": "healthy"|"error"
    }
  → HTTP 200 si OK, HTTP 503 si Elasticsearch KO

Toute autre route → HTTP 404
```

### Comportement de résilience

```
- Connexion RabbitMQ perdue: retry toutes les 5 secondes (loop async)
- Message malformé (JSON parse error): nack + logger, continuer
- Erreur Elasticsearch sur indexation: nack + logger (le message sera perdu)
- Le service reste UP même si ES ou RabbitMQ est temporairement indisponible
  (la probe readiness retourne 503, K8s ne lui envoie plus de trafic)
```

---

## App 4 — Reporting Job (Go) {#app-4-reporting-go}

### Rôle

Job ponctuel (CronJob K8s) qui s'exécute à minuit.
Se connecte à MySQL, compte les produits, envoie le résultat sur MS Teams.

### Structure des fichiers

```
reporting/
├── main.go           # Tout le code (simple, un seul fichier)
├── go.mod
└── go.sum
```

### Dépendances Go

```
Module: github.com/kubiquest/reporting

Dépendances:
- github.com/go-sql-driver/mysql v1.7.1  (driver MySQL)
- net/http (standard library — pour POST Teams webhook)
- database/sql (standard library)
- encoding/json (standard library)
- fmt, log, os (standard library)
```

### Variables d'environnement attendues

```ini
DB_HOST=mysql.databases.svc.cluster.local
DB_PORT=3306
DB_NAME=kubiquest
MYSQL_USER=kubiuser
MYSQL_PASSWORD=...
MSTEAMS_WEBHOOK_URL=https://your-tenant.webhook.office.com/...
```

### Logique de `main.go`

```
func main():

1. Lire les variables d'environnement
   - DB_HOST, DB_PORT, DB_NAME, MYSQL_USER, MYSQL_PASSWORD
   - MSTEAMS_WEBHOOK_URL
   - Si une variable est manquante: log.Fatal + exit

2. Connexion MySQL
   dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s", user, pass, host, port, dbname)
   db, err := sql.Open("mysql", dsn)
   → Si erreur: log.Fatal

3. Ping MySQL (vérifier que la connexion est réelle)
   db.Ping() → Si erreur: log.Fatal

4. Compter les produits
   var count int
   db.QueryRow("SELECT COUNT(*) FROM products").Scan(&count)
   → Si erreur: log.Fatal

5. Fermer la connexion MySQL
   db.Close()

6. Construire le payload MS Teams
   payload := map[string]interface{}{
     "type":    "MessageCard",
     "context": "http://schema.org/extensions",
     "text":    fmt.Sprintf("**KubiQuest Daily Report** — Products in database: **%d**", count),
   }
   jsonBody, _ := json.Marshal(payload)

7. Envoyer HTTP POST au webhook Teams
   resp, err := http.Post(webhookURL, "application/json", bytes.NewBuffer(jsonBody))
   → Si erreur ou status != 200: log.Fatal

8. Logger le succès
   log.Printf("Report sent successfully: %d products", count)
   → Le process termine normalement (exit 0)
   → K8s marquera le Job comme "Succeeded"
```

### Format du message MS Teams

```json
{
  "@type": "MessageCard",
  "@context": "http://schema.org/extensions",
  "themeColor": "0076D7",
  "summary": "KubiQuest Daily Report",
  "sections": [{
    "activityTitle": "KubiQuest Daily Report",
    "activitySubtitle": "Automated report - midnight run",
    "facts": [{
      "name": "Products in database:",
      "value": "42"
    }, {
      "name": "Report date:",
      "value": "2026-02-24 00:00 UTC"
    }],
    "markdown": true
  }]
}
```

---

## Ordre de développement recommandé {#ordre}

### Phase 1 — Backend first (débloquer les autres)

```
1. API Laravel
   a. Initialiser le projet Laravel: composer create-project laravel/laravel api
   b. Configurer .env (MySQL, RabbitMQ, Elasticsearch)
   c. Créer la migration products
   d. Créer le Model Product
   e. Implémenter RabbitMQService (connexion + publish)
   f. Implémenter ElasticsearchService (connexion + search + ping)
   g. Implémenter HealthController (tester en local avec docker-compose)
   h. Implémenter ProductController (CRUD MySQL + publish RabbitMQ)
   i. Implémenter SearchController (Elasticsearch)
   j. Configurer CORS
   k. Tester tous les endpoints avec curl ou Postman
```

### Phase 2 — Indexer (valide RabbitMQ + Elasticsearch end-to-end)

```
2. Indexer Node.JS
   a. Initialiser: npm init
   b. Implémenter health.js (HTTP server)
   c. Implémenter elasticsearch.js (client + index/delete)
   d. Implémenter consumer.js (connexion RabbitMQ + traitement)
   e. Implémenter index.js (orchestration)
   f. Tester: créer un produit via l'API → vérifier qu'il est indexé dans ES
```

### Phase 3 — Reporting (indépendant)

```
3. Reporting Go
   a. go mod init github.com/kubiquest/reporting
   b. Écrire main.go
   c. go mod tidy (télécharger le driver MySQL)
   d. Tester en local: go run main.go
   e. Configurer un vrai webhook Teams pour valider la livraison
```

### Phase 4 — Frontend (tout le reste doit fonctionner)

```
4. Frontend Angular
   a. Initialiser: ng new frontend --standalone --routing=false --style=scss
   b. Créer les modèles (Product, Health)
   c. Créer ApiService avec HttpClient
   d. Créer HealthComponent
   e. Créer AddProductComponent (formulaire)
   f. Créer ProductCardComponent (card + delete)
   g. Créer ProductListComponent (grille + search bar)
   h. Assembler dans AppComponent
   i. Vérifier le layout (3 colonnes, responsive)
   j. Tester end-to-end: créer → apparaît dans la liste → supprimer → disparaît
```

### Phase 5 — Docker & intégration

```
5. Dockerisation
   a. Adapter les Dockerfiles à l'arborescence réelle de chaque app
   b. Builder chaque image localement: docker build
   c. Tester avec docker-compose (optionnel mais très utile)
   d. Pusher sur ghcr.io
   e. Déployer sur Kubernetes et valider end-to-end
```

### Environnement de développement local recommandé

Créer un `docker-compose.dev.yml` à la racine pour avoir MySQL, RabbitMQ et Elasticsearch disponibles localement pendant le développement :

```yaml
# docker-compose.dev.yml — NE PAS COMMITER avec de vraies credentials
services:
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: kubiquest
      MYSQL_USER: kubiuser
      MYSQL_PASSWORD: kubipassword
    ports:
      - "3306:3306"

  rabbitmq:
    image: rabbitmq:3-management
    environment:
      RABBITMQ_DEFAULT_USER: kubiuser
      RABBITMQ_DEFAULT_PASS: kubipassword
    ports:
      - "5672:5672"
      - "15672:15672"  # Management UI

  elasticsearch:
    image: elasticsearch:8.12.0
    environment:
      discovery.type: single-node
      xpack.security.enabled: "false"  # Désactivé en dev seulement
    ports:
      - "9200:9200"
```

