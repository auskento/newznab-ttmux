# All-in-One Newznab-tmux Docker Image
# Self-contained: Clones source from GitHub, installs all OS/software, configures everything
# Services: PHP-FPM, Nginx, MariaDB, Redis, Meilisearch, Supervisor

# ============================================================================
# Build Stage: Clone source and build application
# ============================================================================
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Version control
    git \
    # Build tools
    build-essential \
    curl \
    wget \
    ca-certificates \
    # PHP and build tools
    php-cli \
    php-pdo-mysql \
    php-curl \
    php-gd \
    php-zip \
    php-intl \
    php-mbstring \
    php-xml \
    php-bcmath \
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
RUN composer install --no-dev --optimize-autoloader

# Install frontend dependencies and build assets
RUN npm install && npm run build

# ============================================================================
# Runtime Stage: All-in-One Production Container
# ============================================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PHP_MEMORY_LIMIT=512M \
    PHP_MAX_EXECUTION_TIME=300 \
    MEILISEARCH_ENV=production

# Install all OS and runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Web server
    nginx \
    # PHP runtime
    php-fpm \
    php-cli \
    php-pdo-mysql \
    php-curl \
    php-gd \
    php-zip \
    php-intl \
    php-mbstring \
    php-xml \
    php-bcmath \
    # Database server
    mariadb-server \
    # Cache and job queue
    redis-server \
    # Media processing tools
    unrar \
    p7zip-full \
    ffmpeg \
    mediainfo \
    # Process management
    supervisor \
    # Utilities
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    # Build tools for Meilisearch compilation
    build-essential \
    rustc \
    cargo \
    && rm -rf /var/lib/apt/lists/*

# Install Meilisearch from source
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y -q && \
    . $HOME/.cargo/env && \
    cargo install meilisearch --locked --quiet && \
    cp /root/.cargo/bin/meilisearch /usr/local/bin/ && \
    rm -rf /root/.cargo

WORKDIR /var/www/newznab

# Copy built application from builder stage
COPY --from=builder /var/www/newznab /var/www/newznab

# Copy configuration files
COPY php.ini /etc/php/8.3/fpm/php.ini
COPY php.ini /etc/php/8.3/cli/php.ini
COPY www.conf /etc/php/8.3/fpm/pool.d/www.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Prepare directories and set permissions
RUN mkdir -p /etc/nginx/sites-enabled && \
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default && \
    mkdir -p /var/log/supervisor /run/php /data/mysql /data/redis /data/meilisearch && \
    chown -R www-data:www-data /var/www/newznab /var/log/supervisor /run/php && \
    chmod -R 755 /var/www/newznab && \
    chmod -R 775 /var/www/newznab/storage /var/www/newznab/bootstrap/cache && \
    chmod +x /docker-entrypoint.sh && \
    chown -R mysql:mysql /data/mysql && \
    chown -R redis:redis /data/redis && \
    chmod 700 /data/mysql

# Expose web server port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:80/ || exit 1

# Start all services via entrypoint
CMD ["/docker-entrypoint.sh"]
