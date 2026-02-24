# Build context: repository root
# Example: docker build -f "1. App/docker/indexer/Dockerfile" -t ghcr.io/kubiquest/indexer:latest .

# Stage 1: Install Node dependencies
FROM node:20-alpine AS builder

WORKDIR /app

COPY 1.\ App/indexer/package*.json ./
RUN npm ci --only=production --prefer-offline

# Stage 2: Runtime image
FROM node:20-alpine AS runner

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY 1.\ App/indexer/ .

# Run as non-root user (node user, uid=1000)
USER node

EXPOSE 3000

CMD ["node", "src/index.js"]
