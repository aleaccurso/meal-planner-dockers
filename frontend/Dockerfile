# ---- Build stage ----
FROM node:18-alpine AS builder

# Install Git and SSH client for cloning
RUN apk add --no-cache git openssh-client

# Set up SSH known_hosts for GitHub
RUN mkdir -p -m 0700 ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts

# Set working directory
WORKDIR /app

# Build arg to invalidate only the git clone layer (doesn't affect other layers)
# Change this value to fetch latest commits without rebuilding dependencies
# This is used only for cache-busting, we always clone from 'main' branch
ARG CACHE_BUST=1
RUN echo "Cache bust: ${CACHE_BUST}"

# Clone the latest commit from main branch (always use 'main')
# This layer is cached until CACHE_BUST changes
# This uses BuildKit SSH mount to securely access the repository
RUN --mount=type=ssh \
    rm -rf /app/* /app/.[!.]* 2>/dev/null || true && \
    git clone --depth 1 --branch main git@github.com:aleaccurso/meal-planner.git /app && \
    cd /app && \
    git rev-parse HEAD > /tmp/git-commit.txt && \
    git log -1 --format="📌 Commit: %H - %s"

# Install dependencies (cached separately - only rebuilds if package files change)
RUN npm install

# Build the application (cached separately - only rebuilds if source code changes)
RUN npm run build

# ---- Runtime stage ----
FROM nginx:alpine

# Copy the built files from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]

