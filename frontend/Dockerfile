# syntax=docker/dockerfile:1

# ---- Build stage ----
FROM node:25 AS builder

# Git is pre-installed in Debian-based node image
# No need to install it separately

# Set working directory
WORKDIR /app

# Build args
ARG GIT_AUTH_TOKEN
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

# Container Manager's compose build doesn't support BuildKit's git-context
# ADD + build.secrets (its compose parser rejects `secrets` under `build:`,
# and DOCKER_BUILDKIT=1 has no effect there), so auth can't use the reserved
# GIT_AUTH_TOKEN build secret. Instead GIT_AUTH_TOKEN is a plain build ARG,
# used only in this discarded builder stage, and passed to git as an HTTP
# header (never a URL) so it never appears in build logs or git's own
# output. It still ends up in this builder stage's `docker history` (not
# the final image) - the standard pre-BuildKit-secrets tradeoff.
RUN AUTH_HEADER="AUTHORIZATION: basic $(printf '%s' "x-access-token:${GIT_AUTH_TOKEN}" | base64 -w0)" && \
    git clone -c http.extraheader="${AUTH_HEADER}" --branch main --single-branch \
      https://github.com/aleaccurso/meal-planner.git /app

# Record the commit and verify the clone succeeded
RUN COMMIT_HASH=`git -C /app rev-parse HEAD 2>/dev/null || echo "unknown"` && \
    echo "✓ Cloned meal-planner (commit: ${COMMIT_HASH})" && \
    if [ ! -f /app/package.json ]; then \
        echo "ERROR: Repository clone failed - package.json not found"; \
        exit 1; \
    fi && \
    echo "${COMMIT_HASH}" > /app/COMMIT_SHA && \
    rm -rf /app/.git

# Install firebase package
RUN npm install firebase

# Install dependencies
RUN npm install

# Build the application
# VITE_APP_API_BASE_URL is available as environment variable for Vite to embed
RUN echo "Building with VITE_APP_API_BASE_URL=${VITE_APP_API_BASE_URL}" && \
    npm run build

# ---- Runtime stage ----
FROM nginx:alpine

# Install gettext for envsubst
RUN apk add --no-cache gettext

# Copy nginx configuration template
COPY nginx.conf /etc/nginx/templates/default.conf.template

# Copy built files
COPY --from=builder /app/dist /usr/share/nginx/html
COPY --from=builder /app/COMMIT_SHA /usr/share/nginx/html/COMMIT_SHA

# Expose port
EXPOSE 80

# Start nginx with environment variable substitution
CMD ["/bin/sh", "-c", "envsubst '$$VITE_APP_BACKEND_HOST $$VITE_APP_BACKEND_PORT' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
