# ---- Build stage ----
FROM node:25 AS builder

# Git is pre-installed in Debian-based node image
# No need to install it separately

# Set working directory
WORKDIR /app

# Build args
ARG CACHE_BUST
ARG GITHUB_TOKEN
ARG GITHUB_USERNAME
ARG VITE_APP_BACKEND_HOST
ARG VITE_APP_BACKEND_PORT

# # Set Vite environment variables from build args
# # These MUST be set as ENV (not just ARG) so Vite can access them during build
# # Vite embeds environment variables at build time, not runtime
# ENV VITE_APP_BACKEND_HOST=${VITE_APP_BACKEND_HOST}
# ENV VITE_APP_BACKEND_PORT=${VITE_APP_BACKEND_PORT}

# Use CACHE_BUST to ensure fresh clone on every build (invalidates cache when changed)
RUN echo "Cache bust: ${CACHE_BUST}" && \
    if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_USERNAME" ]; then \
        echo "ERROR: GITHUB_TOKEN and GITHUB_USERNAME must be provided as build args"; \
        exit 1; \
    fi && \
    echo "Cloning repository via HTTPS..." && \
    git clone --depth 1 --no-tags --single-branch -b main https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/aleaccurso/meal-planner.git . && \
    COMMIT_HASH=`git rev-parse HEAD 2>/dev/null || echo "unknown"` && \
    echo "✓ Successfully cloned meal-planner repository (commit: $${COMMIT_HASH})" && \
    echo "✓ Repository is up-to-date with latest from main branch" && \
    if [ ! -f package.json ]; then \
        echo "ERROR: Repository clone failed - package.json not found"; \
        exit 1; \
    fi && \
    rm -rf .git

# Install dependencies
RUN npm install

# Build the application
# VITE_APP_BACKEND_HOST and VITE_APP_BACKEND_PORT are now available as environment variables
RUN echo "Building with VITE_APP_BACKEND_HOST=${VITE_APP_BACKEND_HOST} and VITE_APP_BACKEND_PORT=${VITE_APP_BACKEND_PORT}" && \
    npm run build

# ---- Runtime stage ----
FROM nginx:alpine

# Install gettext for envsubst
RUN apk add --no-cache gettext

# Copy nginx configuration template
COPY nginx.conf /etc/nginx/templates/default.conf.template

# Copy built files
COPY --from=builder /app/dist /usr/share/nginx/html

# Expose port
EXPOSE 80

# Start nginx with environment variable substitution
CMD ["/bin/sh", "-c", "envsubst '$$VITE_APP_BACKEND_HOST $$VITE_APP_BACKEND_PORT' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
