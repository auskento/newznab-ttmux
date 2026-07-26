# All-in-One Newznab-tmux Docker Image
# Self-contained: Clones source from GitHub, installs all OS/software, configures everything
# Services: PHP-FPM, Nginx, MariaDB, Redis, Meilisearch, Supervisor

# ============================================================================
# Build Stage: Clone source and build application
# ============================================================================
FROM debian:13-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Add PHP 8.3 repository and install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    lsb-release ca-certificates curl gnupg \
    && curl https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury.gpg \
    && echo "deb [signed-by=/etc/apt/trusted.gpg.d/sury.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    # Version control
    git \
    # Build tools
    build-essential \
    # PHP 8.4 and build tools (required by newznab-tmux)
    php8.4-cli \
    php8.4-pdo-mysql \
    php8.4-curl \
    php8.4-gd \
    php8.4-zip \
    php8.4-intl \
    php8.4-mbstring \
    php8.4-xml \
    php8.4-bcmath \
    composer \
    # Node.js for frontend build
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/newznab

# Clone newznab-tmux from GitHub
RUN git clone --depth 1 https://github.com/NNTmux/newznab-tmux.git . && \
    rm -rf .git .github

# Install PHP dependencies
RUN COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --ignore-platform-reqs

# Install frontend dependencies and build assets
RUN npm install && npm run build

# ============================================================================
# Runtime Stage: All-in-One Production Container
# ============================================================================
FROM debian:13-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PHP_MEMORY_LIMIT=512M \
    PHP_MAX_EXECUTION_TIME=300 \
    MEILISEARCH_ENV=production

# Add PHP 8.3 repository and install all runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    lsb-release ca-certificates curl gnupg \
    && curl https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury.gpg \
    && echo "deb [signed-by=/etc/apt/trusted.gpg.d/sury.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    # Web server
    nginx \
    # PHP 8.4 runtime
    php8.4-fpm \
    php8.4-cli \
    php8.4-pdo-mysql \
    php8.4-curl \
    php8.4-gd \
    php8.4-zip \
    php8.4-intl \
    php8.4-mbstring \
    php8.4-xml \
    php8.4-bcmath \
    # Database server
    mariadb-server \
    # Cache and job queue
    redis-server \
    # Media processing tools
    unar \
    p7zip-full \
    ffmpeg \
    mediainfo \
    # Process management
    supervisor \
    # Utilities
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Meilisearch (pre-built binary)
RUN curl -L https://github.com/meilisearch/meilisearch/releases/download/v1.11.3/meilisearch-linux-amd64 \
    -o /usr/local/bin/meilisearch && \
    chmod +x /usr/local/bin/meilisearch

WORKDIR /var/www/newznab

# Copy built application from builder stage
COPY --from=builder /var/www/newznab /var/www/newznab

# Copy configuration files
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Prepare directories and set permissions
RUN mkdir -p /etc/nginx/sites-enabled && \
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default && \
    mkdir -p /var/log/supervisor /run/php /data/mysql /data/redis /data/meilisearch && \
    chown -R www-data:www-data /var/www/newznab /var/log/supervisor && \
    chmod -R 755 /var/www/newznab && \
    chmod -R 775 /var/www/newznab/storage /var/www/newznab/bootstrap/cache && \
    chmod +x /docker-entrypoint.sh && \
    chown -R mysql:mysql /data/mysql && \
    chown -R redis:redis /data/redis && \
    chmod 700 /data/mysql && \
    # PHP-FPM configuration (modify default pool)
    sed -i 's/^listen = .*/listen = 127.0.0.1:9000/' /etc/php/8.4/fpm/pool.d/www.conf && \
    sed -i 's/^;pm.max_children = .*/pm.max_children = 50/' /etc/php/8.4/fpm/pool.d/www.conf && \
    sed -i 's/^;pm.start_servers = .*/pm.start_servers = 5/' /etc/php/8.4/fpm/pool.d/www.conf && \
    sed -i 's/^;pm.min_spare_servers = .*/pm.min_spare_servers = 3/' /etc/php/8.4/fpm/pool.d/www.conf && \
    sed -i 's/^;pm.max_spare_servers = .*/pm.max_spare_servers = 10/' /etc/php/8.4/fpm/pool.d/www.conf && \
    sed -i 's/^php_admin_value\[memory_limit\] = .*/php_admin_value[memory_limit] = 512M/' /etc/php/8.4/fpm/pool.d/www.conf

# Expose web server port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:80/ || exit 1

# Start all services via entrypoint
CMD ["/docker-entrypoint.sh"]
