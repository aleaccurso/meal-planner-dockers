# syntax=docker/dockerfile:1
# ---- Build stage ----
FROM node:26.4.0-alpine3.23 AS builder

# Patch Alpine packages and install git
RUN apk upgrade --no-cache && \
    apk add --no-cache git

# Set working directory
WORKDIR /app

ARG VITE_APP_API_BASE_URL
ARG VITE_APP_FIREBASE_API_KEY
ARG VITE_APP_FIREBASE_AUTH_DOMAIN
ARG VITE_APP_FIREBASE_PROJECT_ID
ARG VITE_APP_FIREBASE_STORAGE_BUCKET
ARG VITE_APP_FIREBASE_MESSAGING_SENDER_ID
ARG VITE_APP_FIREBASE_APP_ID
ARG VITE_APP_USERS_AVATAR_FOLDER
ARG VITE_APP_RECIPES_IMAGES_FOLDER

# Expose all Vite env vars so they get embedded into the bundle at build time
ENV VITE_APP_API_BASE_URL=${VITE_APP_API_BASE_URL} \
    VITE_APP_FIREBASE_API_KEY=${VITE_APP_FIREBASE_API_KEY} \
    VITE_APP_FIREBASE_AUTH_DOMAIN=${VITE_APP_FIREBASE_AUTH_DOMAIN} \
    VITE_APP_FIREBASE_PROJECT_ID=${VITE_APP_FIREBASE_PROJECT_ID} \
    VITE_APP_FIREBASE_STORAGE_BUCKET=${VITE_APP_FIREBASE_STORAGE_BUCKET} \
    VITE_APP_FIREBASE_MESSAGING_SENDER_ID=${VITE_APP_FIREBASE_MESSAGING_SENDER_ID} \
    VITE_APP_FIREBASE_APP_ID=${VITE_APP_FIREBASE_APP_ID} \
    VITE_APP_USERS_AVATAR_FOLDER=${VITE_APP_USERS_AVATAR_FOLDER} \
    VITE_APP_RECIPES_IMAGES_FOLDER=${VITE_APP_RECIPES_IMAGES_FOLDER}

# Clone repository using BuildKit secrets (never written to any image layer)
RUN --mount=type=secret,id=github_token \
    --mount=type=secret,id=github_username \
    GITHUB_TOKEN=$(cat /run/secrets/github_token) && \
    GITHUB_USERNAME=$(cat /run/secrets/github_username) && \
    if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_USERNAME" ]; then \
        echo "ERROR: github_token and github_username secrets must be provided"; \
        exit 1; \
    fi && \
    echo "Cloning repository via HTTPS..." && \
    git clone --depth 1 --no-tags --single-branch -b main https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/aleaccurso/meal-planner.git . && \
    COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "unknown") && \
    echo "Successfully cloned meal-planner repository (commit: ${COMMIT_HASH})" && \
    if [ ! -f package.json ]; then \
        echo "ERROR: Repository clone failed - package.json not found"; \
        exit 1; \
    fi && \
    rm -rf .git

# Install dependencies
RUN npm install

# Build the application
RUN echo "Building with VITE_APP_API_BASE_URL=${VITE_APP_API_BASE_URL}" && \
    npm run build

# ---- Runtime stage ----
FROM nginx:stable-alpine3.23

# Patch Alpine packages and install envsubst
RUN apk upgrade --no-cache && \
    apk add --no-cache gettext

# Copy nginx configuration template
COPY nginx.conf /etc/nginx/templates/default.conf.template

# Copy built files
COPY --from=builder /app/dist /usr/share/nginx/html

# Expose port
EXPOSE 80

# Start nginx with environment variable substitution
CMD ["/bin/sh", "-c", "envsubst '$$VITE_APP_BACKEND_HOST $$VITE_APP_BACKEND_PORT' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
