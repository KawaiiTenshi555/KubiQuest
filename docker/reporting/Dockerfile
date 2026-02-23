# ─────────────────────────────────────────
# Stage 1: Build Go binary
# ─────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Download dependencies first (layer cache optimization)
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build a static binary
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o /reporting ./...

# ─────────────────────────────────────────
# Stage 2: Minimal runtime image
# ─────────────────────────────────────────
FROM scratch AS runner

# Copy CA certificates for HTTPS (Teams webhook)
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy compiled binary
COPY --from=builder /reporting /reporting

# Run as non-root (uid 65534 = nobody, which scratch supports)
USER 65534

ENTRYPOINT ["/reporting"]
