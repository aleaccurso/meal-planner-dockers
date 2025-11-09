# ---- Build stage ----
FROM node:20 AS builder

# Git is pre-installed in Debian-based node image
# No need to install it separately

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
    git clone --depth 1 -b main git@github.com:aleaccurso/meal-planner.git . || { \
        echo "ERROR: Git clone failed via SSH."; \
        exit 1; \
    } && \
    rm -rf .git && \
    git rev-parse HEAD > /tmp/git-commit.txt || true

# Install dependencies
RUN npm install

# Build the application
RUN npm run build

# ---- Runtime stage ----
FROM nginx:alpine

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built files
COPY --from=builder /app/dist /usr/share/nginx/html

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
