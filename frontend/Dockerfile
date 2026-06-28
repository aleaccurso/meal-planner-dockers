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

ARG GITHUB_TOKEN
ARG GITHUB_USERNAME

RUN if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_USERNAME" ]; then \
        echo "ERROR: GITHUB_TOKEN and GITHUB_USERNAME must be provided as build args"; \
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
RUN npm install && npm install firebase

# Build the application
RUN echo "Building with VITE_APP_API_BASE_URL=${VITE_APP_API_BASE_URL}" && \
    npm run build

# ---- Runtime stage ----
FROM nginx:stable-alpine3.23

# Patch Alpine packages
RUN apk upgrade --no-cache

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built files
COPY --from=builder /app/dist /usr/share/nginx/html

# Expose port
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
