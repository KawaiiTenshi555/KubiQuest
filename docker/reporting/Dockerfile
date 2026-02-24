# Build context: root of the repository
# docker build -f docker/reporting/Dockerfile -t ghcr.io/kubiquest/reporting:latest .

# ─────────────────────────────────────────
# Stage 1: Build Go binary
# ─────────────────────────────────────────
FROM golang:1.22-alpine AS builder

# Install CA certs (needed to copy them into scratch image)
RUN apk add --no-cache ca-certificates

WORKDIR /app

COPY reporting/go.mod reporting/go.sum ./
RUN go mod download

COPY reporting/ .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o /reporting ./...

# ─────────────────────────────────────────
# Stage 2: Minimal runtime (scratch)
# ─────────────────────────────────────────
FROM scratch AS runner

# Copy CA certs for HTTPS (MS Teams webhook)
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=builder /reporting /reporting

USER 65534

ENTRYPOINT ["/reporting"]
