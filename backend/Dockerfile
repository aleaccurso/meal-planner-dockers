# syntax=docker/dockerfile:1

# ---- Build stage ----
FROM golang:1.25.3 AS builder

# Git is pre-installed in Debian-based golang image
# No need to install it separately

# Enable automatic toolchain download if needed
ENV GOTOOLCHAIN=auto

# Set working directory
WORKDIR /app

# Container Manager's compose build doesn't support BuildKit's git-context
# ADD + build.secrets (its compose parser rejects `secrets` under `build:`,
# and DOCKER_BUILDKIT=1 has no effect there), so auth can't use the reserved
# GIT_AUTH_TOKEN build secret. Instead GIT_AUTH_TOKEN is a plain build ARG,
# used only in this discarded builder stage, and passed to git as an HTTP
# header (never a URL) so it never appears in build logs or git's own
# output. It still ends up in this builder stage's `docker history` (not
# the final image) - the standard pre-BuildKit-secrets tradeoff.
ARG GIT_AUTH_TOKEN
ARG CACHEBUST=1
RUN AUTH_HEADER="AUTHORIZATION: basic $(printf '%s' "x-access-token:${GIT_AUTH_TOKEN}" | base64 -w0)" && \
    git clone -c http.extraheader="${AUTH_HEADER}" --branch main --single-branch \
      https://github.com/aleaccurso/meal-planner-backend.git /app

# Record the commit and verify the clone succeeded
RUN COMMIT_HASH=`git -C /app rev-parse HEAD 2>/dev/null || echo "unknown"` && \
    echo "✓ Cloned meal-planner-backend (commit: ${COMMIT_HASH})" && \
    if [ ! -f /app/go.mod ]; then \
        echo "ERROR: Repository clone failed - go.mod not found"; \
        exit 1; \
    fi && \
    echo "${COMMIT_HASH}" > /app/COMMIT_SHA && \
    rm -rf /app/.git

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
