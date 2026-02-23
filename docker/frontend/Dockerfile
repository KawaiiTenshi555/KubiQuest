# ─────────────────────────────────────────
# Stage 1: Build Angular application
# ─────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies first (layer cache optimization)
COPY package.json package-lock.json ./
RUN npm ci --prefer-offline

# Copy source and build
COPY . .
RUN npm run build -- --configuration production

# ─────────────────────────────────────────
# Stage 2: Serve with nginx
# ─────────────────────────────────────────
FROM nginx:1.25-alpine AS runner

# Remove default nginx content
RUN rm -rf /usr/share/nginx/html/*

# Copy built Angular app
COPY --from=builder /app/dist/*/browser /usr/share/nginx/html

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

# nginx runs as non-root (nginx user uid=101)
USER nginx

CMD ["nginx", "-g", "daemon off;"]
