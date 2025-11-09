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
ARG GITHUB_TOKEN
ARG GITHUB_USERNAME

RUN echo "Cache bust: ${CACHE_BUST}"

# Clone using HTTPS with token
RUN if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_USERNAME" ]; then \
        echo "ERROR: GITHUB_TOKEN and GITHUB_USERNAME must be provided as build args"; \
        exit 1; \
    fi && \
    echo "Checking GitHub connectivity..." && \
    if ! curl -s --connect-timeout 10 --max-time 30 https://github.com > /dev/null; then \
        echo "ERROR: Cannot reach GitHub. Check network connectivity and firewall settings."; \
        exit 1; \
    fi && \
    echo "GitHub is reachable. Cloning repository..." && \
    git clone --depth 1 -b main https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/aleaccurso/meal-planner-backend.git . && \
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
