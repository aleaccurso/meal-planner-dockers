# syntax=docker/dockerfile:1
# ---- Build stage ----
FROM golang:1.26-alpine AS builder

# Patch Alpine packages to latest versions before anything else
RUN apk upgrade --no-cache

# Alpine golang image does not include git
RUN apk add --no-cache git

# Enable automatic toolchain download if needed
ENV GOTOOLCHAIN=auto

# Set working directory
WORKDIR /app

# Use CACHE_BUST to ensure fresh clone on every build (invalidates cache when changed)
# Secrets are mounted at runtime only and never written to any image layer
RUN --mount=type=secret,id=github_token \
    --mount=type=secret,id=github_username \
    GITHUB_TOKEN=$(cat /run/secrets/github_token) && \
    GITHUB_USERNAME=$(cat /run/secrets/github_username) && \
    CACHE_BUST=$(date +%s) && \
    if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_USERNAME" ]; then \
        echo "ERROR: github_token and github_username secrets must be provided"; \
        exit 1; \
    fi && \
    echo "Cloning repository via HTTPS..." && \
    git clone --depth 1 --no-tags --single-branch -b main https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/aleaccurso/meal-planner-backend.git . && \
    COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "unknown") && \
    echo "Successfully cloned meal-planner-backend repository (commit: ${COMMIT_HASH})" && \
    echo "Repository is up-to-date with latest from main branch" && \
    if [ ! -f go.mod ]; then \
        echo "ERROR: Repository clone failed - go.mod not found"; \
        exit 1; \
    fi && \
    rm -rf .git

# Verify repository was cloned
RUN if [ ! -f go.mod ]; then \
        echo "ERROR: Repository clone failed."; \
        exit 1; \
    fi

# Download Go modules
RUN go mod download

# Build the binary with CGO disabled for Alpine compatibility
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# ---- Runtime stage ----
FROM alpine:3.22

# Build arg for port (must be redeclared in this stage)
ARG BACKEND_PORT

# Install wget and netcat for healthcheck
RUN apk add --no-cache wget netcat-openbsd

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

WORKDIR /app

# Copy binary and migrations from builder
COPY --from=builder /app/main .
COPY --from=builder /app/database/migrations ./database/migrations

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port (using build arg with default value)
EXPOSE ${BACKEND_PORT}

# Run
CMD ["./main"]
