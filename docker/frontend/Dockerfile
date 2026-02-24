# Build context: root of the repository
# docker build -f docker/frontend/Dockerfile -t ghcr.io/kubiquest/frontend:latest .

# ─────────────────────────────────────────
# Stage 1: Build Angular application
# ─────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies first (layer cache optimization)
COPY frontend/package.json frontend/package-lock.json* ./
RUN npm ci --prefer-offline

# Copy source and build for production
COPY frontend/ .
RUN npm run build -- --configuration production

# ─────────────────────────────────────────
# Stage 2: Serve with nginx
# ─────────────────────────────────────────
FROM nginx:1.25-alpine AS runner

RUN rm -rf /usr/share/nginx/html/*

# Angular 17 outputs to dist/<project-name>/browser
COPY --from=builder /app/dist/kubiquest-frontend/browser /usr/share/nginx/html

COPY docker/frontend/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
