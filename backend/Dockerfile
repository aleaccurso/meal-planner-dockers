# ---- Build stage ----
FROM golang:1.23 AS builder

# Git is pre-installed in Debian-based golang image
# No need to install it separately

# Enable automatic toolchain download if needed
ENV GOTOOLCHAIN=auto

# Set working directory
WORKDIR /app

# Build args
ARG CACHE_BUST=1

RUN echo "Cache bust: ${CACHE_BUST}"

# Configure SSH and clone using SSH
# --mount=type=ssh mounts the SSH agent socket
RUN --mount=type=ssh \
    mkdir -p -m 0700 ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null || true && \
    echo "Testing SSH connection to GitHub..." && \
    ssh -T git@github.com 2>&1 || echo "SSH test completed (exit code expected)" && \
    echo "Cloning repository via SSH..." && \
    git clone --depth 1 -b main git@github.com:aleaccurso/meal-planner-backend.git . || { \
        echo "ERROR: Git clone failed via SSH."; \
        exit 1; \
    } && \
    rm -rf .git && \
    git rev-parse HEAD > /tmp/git-commit.txt || true

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

# Install wget for healthcheck
RUN apk add --no-cache wget

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
