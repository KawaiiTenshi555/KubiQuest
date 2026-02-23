# ─────────────────────────────────────────
# Stage 1: Install Node dependencies
# ─────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Install production dependencies only
COPY package.json package-lock.json ./
RUN npm ci --only=production --prefer-offline

# ─────────────────────────────────────────
# Stage 2: Runtime image
# ─────────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

# Copy production node_modules from builder
COPY --from=builder /app/node_modules ./node_modules

# Copy application source
COPY . .

# Run as non-root user (node user, uid=1000)
USER node

EXPOSE 3000

CMD ["node", "src/index.js"]
