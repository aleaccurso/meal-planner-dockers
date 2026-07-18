# syntax=docker/dockerfile:1

# ---- Build stage ----
FROM golang:1.25.3 AS builder

# Git is pre-installed in Debian-based golang image
# No need to install it separately

# Enable automatic toolchain download if needed
ENV GOTOOLCHAIN=auto

# Set working directory
WORKDIR /app

# Build args
ARG GITHUB_TOKEN
ARG GITHUB_USERNAME

RUN if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_USERNAME" ]; then \
        echo "ERROR: GITHUB_TOKEN and GITHUB_USERNAME must be provided as build args"; \
        exit 1; \
    fi

# BuildKit's git-context ADD resolves the `main` ref against GitHub on
# every build and only reuses the cached layer if the commit is unchanged -
# no manual cache-busting needed, works the same locally and in Container
# Manager (which offers no "build without cache" option).
ADD --keep-git-dir=true https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/aleaccurso/meal-planner-backend.git#main /app

# Record the commit and verify the clone succeeded
RUN COMMIT_HASH=`git rev-parse HEAD 2>/dev/null || echo "unknown"` && \
    echo "✓ Cloned meal-planner-backend (commit: ${COMMIT_HASH})" && \
    if [ ! -f go.mod ]; then \
        echo "ERROR: Repository clone failed - go.mod not found"; \
        exit 1; \
    fi && \
    echo "${COMMIT_HASH}" > /app/COMMIT_SHA && \
    rm -rf .git

# Download Go modules
RUN go mod download

# Build the binary with CGO disabled for Alpine compatibility
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# ---- Runtime stage ----
FROM alpine:3.19

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
COPY --from=builder /app/COMMIT_SHA .

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port (using build arg with default value)
EXPOSE ${BACKEND_PORT}

# Run
CMD ["./main"]
