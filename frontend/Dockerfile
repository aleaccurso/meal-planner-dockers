# ---- Build stage ----
FROM node:20 AS builder

# Git is pre-installed in Debian-based node image
# No need to install it separately

# Set working directory
WORKDIR /app

# Build args
ARG CACHE_BUST=-1
ARG GITHUB_TOKEN
ARG GITHUB_USERNAME

RUN echo "Cache bust: ${CACHE_BUST}"

# Clone using HTTPS with token
RUN if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_USERNAME" ]; then \
        echo "ERROR: GITHUB_TOKEN and GITHUB_USERNAME must be provided as build args"; \
        exit 1; \
    fi && \
    echo "Testing network connectivity..." && \
    if ! ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then \
        echo "WARNING: Cannot reach external network (8.8.8.8)"; \
    fi && \
    if ! nslookup github.com > /dev/null 2>&1; then \
        echo "ERROR: Cannot resolve github.com. DNS issue detected."; \
        echo "On Synology NAS, check:"; \
        echo "  1. DNS settings in Control Panel > Network > Network Interface"; \
        echo "  2. Try using 8.8.8.8 or 1.1.1.1 as DNS server"; \
        echo "  3. Check firewall rules"; \
        exit 1; \
    fi && \
    echo "Cloning repository via HTTPS..." && \
    git clone --depth 1 -b main https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/aleaccurso/meal-planner.git . || { \
        echo "ERROR: Git clone failed via HTTPS."; \
        echo "Possible causes:"; \
        echo "  1. Network/DNS issue (check above)"; \
        echo "  2. Invalid GITHUB_TOKEN or GITHUB_USERNAME"; \
        echo "  3. Token doesn't have access to repository"; \
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
