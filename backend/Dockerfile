# ---- Build stage ----
FROM golang:1.24.6-alpine AS builder

# Install Git and SSH client for cloning
RUN apk add --no-cache git openssh-client

# Enable automatic toolchain download if needed
ENV GOTOOLCHAIN=auto

# Set working directory
WORKDIR /app

# Set up SSH known_hosts for GitHub
RUN mkdir -p -m 0700 ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts

# Build arg to invalidate only the git clone layer (doesn't affect other layers)
# Change this value to fetch latest commits without rebuilding dependencies
# This is used only for cache-busting, we always clone from 'main' branch
ARG CACHE_BUST=1
RUN echo "Cache bust: ${CACHE_BUST}"

# Clone the repository using SSH (always use 'main' branch)
# This layer is cached until CACHE_BUST changes
# Requires SSH agent to be forwarded from host via --mount=type=ssh
RUN --mount=type=ssh \
    git clone --depth 1 -b main git@github.com:aleaccurso/meal-planner-backend . && \
    git rev-parse HEAD > /tmp/git-commit.txt && \
    git log -1 --format="📌 Commit: %H - %s"

# Verify that repository was cloned successfully
RUN if [ ! -d .git ]; then \
        echo "ERROR: Repository clone failed. Make sure SSH agent is running and key is added." && \
        exit 1; \
    fi

# Download Go modules (cached separately - only rebuilds if go.mod/go.sum change)
RUN go mod download

# Build your Go binary (cached separately - only rebuilds if source code changes)
RUN go build -o main .

# ---- Runtime stage ----
FROM alpine:latest

WORKDIR /app

# Copy only the binary from the builder stage
COPY --from=builder /app/main .

# Expose your app port (adjust as needed)
EXPOSE 8010

# Run the binary
CMD ["./main"]
