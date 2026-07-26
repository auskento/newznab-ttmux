# All-in-One Newznab-tmux Container
# Includes: PHP-FPM, Nginx, MariaDB, Redis, Meilisearch, and Supervisor

FROM php:8.4-fpm-alpine as builder

# Build dependencies
RUN apk add --no-cache \
    alpine-sdk \
    curl-dev \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    oniguruma-dev \
    git \
    nodejs \
    npm \
    composer

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    curl \
    json \
    gd \
    zip \
    intl \
    mbstring \
    xml \
    pcntl

WORKDIR /var/www/newznab

# Copy application files
COPY app/ .

# Install dependencies
RUN composer install --no-dev --optimize-autoloader && \
    npm install && npm run build

# Production stage - All in one
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PHP_MEMORY_LIMIT=512M \
    PHP_MAX_EXECUTION_TIME=300 \
    MEILISEARCH_ENV=production

# Install all required services and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Web server
    nginx \
    # PHP
    php8.3-fpm \
    php8.3-cli \
    php8.3-pdo-mysql \
    php8.3-curl \
    php8.3-gd \
    php8.3-zip \
    php8.3-intl \
    php8.3-mbstring \
    php8.3-xml \
    php8.3-bcmath \
    # Database
    mariadb-server \
    # Cache and Queue
    redis-server \
    # Media tools
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
    # Build tools for Meilisearch
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Rust for Meilisearch
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . $HOME/.cargo/env && \
    cargo install meilisearch --locked

# Copy Meilisearch binary to PATH
RUN cp /root/.cargo/bin/meilisearch /usr/local/bin/

# Create application directory
WORKDIR /var/www/newznab

# Copy application from builder
COPY --from=builder /var/www/newznab /var/www/newznab

# Copy configuration files
COPY php.ini /etc/php/8.3/fpm/php.ini
COPY php.ini /etc/php/8.3/cli/php.ini
COPY www.conf /etc/php/8.3/fpm/pool.d/www.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create nginx configuration for local reverse proxy
RUN mkdir -p /etc/nginx/sites-enabled && \
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Create application initialization script
RUN mkdir -p /docker-entrypoint.d
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Set permissions
RUN chown -R www-data:www-data /var/www/newznab && \
    chmod -R 755 /var/www/newznab && \
    chmod -R 775 /var/www/newznab/storage /var/www/newznab/bootstrap/cache && \
    chmod +x /docker-entrypoint.sh && \
    mkdir -p /var/log/supervisor && \
    mkdir -p /run/php && \
    chown -R www-data:www-data /var/log/supervisor /run/php

# Create data directories
RUN mkdir -p /data/mysql /data/redis /data/meilisearch && \
    chown -R mysql:mysql /data/mysql && \
    chown -R redis:redis /data/redis && \
    chmod 700 /data/mysql

# Expose main web port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

# Start all services
CMD ["/docker-entrypoint.sh"]
