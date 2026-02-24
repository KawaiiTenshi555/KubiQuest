# Build context: repository root
# Example: docker build -f "1. App/docker/frontend/Dockerfile" -t ghcr.io/kubiquest/frontend:latest .

# Stage 1: Build Angular application
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies first (layer cache optimization)
COPY 1.\ App/frontend/package*.json ./
RUN npm ci --prefer-offline

# Copy source and build for production
COPY 1.\ App/frontend/ ./
RUN npm run build -- --configuration production

# Stage 2: Serve with nginx
FROM nginx:1.25-alpine AS runner

RUN rm -rf /usr/share/nginx/html/*

# Angular 17 outputs to dist/<project-name>/browser
COPY --from=builder /app/dist/kubiquest-frontend/browser /usr/share/nginx/html

COPY 1.\ App/docker/frontend/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
