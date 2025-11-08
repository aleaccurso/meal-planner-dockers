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
RUN if [ -z "$GITHUB_TOKEN" ]; then \
        echo "ERROR: GITHUB_TOKEN not provided"; \
        exit 1; \
    fi && \
    git clone --depth 1 -b main \
    https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/aleaccurso/meal-planner-backend.git . && \
    git rev-parse HEAD > /tmp/git-commit.txt && \
    git log -1 --format="📌 Commit: %H - %s"

# Verify repository was cloned
RUN if [ ! -f go.mod ]; then \
        echo "ERROR: Repository clone failed."; \
        exit 1; \
    fi

# Download Go modules
RUN go mod download

# Build the binary
RUN go build -o main .

# ---- Runtime stage ----
FROM alpine:latest

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/main .

# Expose port
EXPOSE 8010

# Run
CMD ["./main"]
