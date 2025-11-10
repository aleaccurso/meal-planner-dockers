# ---- Build stage ----
FROM golang:1.25.3 AS builder

# Git is pre-installed in Debian-based golang image
# No need to install it separately

# Enable automatic toolchain download if needed
ENV GOTOOLCHAIN=auto

# Set working directory
WORKDIR /app

# Build args
ARG CACHE_BUST
ARG GITHUB_TOKEN
ARG GITHUB_USERNAME

# Use CACHE_BUST to ensure fresh clone on every build (invalidates cache when changed)
RUN echo "Cache bust: ${CACHE_BUST}" && \
    if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_USERNAME" ]; then \
        echo "ERROR: GITHUB_TOKEN and GITHUB_USERNAME must be provided as build args"; \
        exit 1; \
    fi && \
    echo "Cloning repository via HTTPS..." && \
    git clone --depth 1 --no-tags --single-branch -b main https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/aleaccurso/meal-planner-backend.git . && \
    COMMIT_HASH=`git rev-parse HEAD 2>/dev/null || echo "unknown"` && \
    echo "✓ Successfully cloned meal-planner-backend repository (commit: $${COMMIT_HASH})" && \
    echo "✓ Repository is up-to-date with latest from main branch" && \
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
FROM alpine:3.19

# Install wget and netcat for healthcheck
RUN apk add --no-cache wget netcat-openbsd

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/main .

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8010

# Run
CMD ["./main"]
