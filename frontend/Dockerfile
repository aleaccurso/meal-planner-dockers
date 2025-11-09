# ---- Build stage ----
FROM node:20 AS builder

# Git is pre-installed in Debian-based node image
# No need to install it separately

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
    git clone --depth 1 -b main https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/aleaccurso/meal-planner.git . && \
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
