# Multi-stage build for newznab-tmux
FROM php:8.4-fpm-alpine as php-base

# Install PHP extensions and dependencies
RUN apk add --no-cache \
    alpine-sdk \
    curl-dev \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    oniguruma-dev \
    gnu-libiconv-dev \
    unrar \
    p7zip \
    ffmpeg \
    mediainfo \
    git \
    nodejs \
    npm \
    composer \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    curl \
    json \
    gd \
    zip \
    intl \
    mbstring \
    xml \
    pcntl \
    && apk del alpine-sdk

# Install GNU libiconv to work around musl libc issues
ENV LD_PRELOAD=/usr/lib/preloadable_libc.so GNU_LIBICONV=all

# Set working directory
WORKDIR /var/www/newznab

# Copy application files
COPY app/ .

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader

# Install frontend dependencies
RUN npm install && npm run build

# Set permissions
RUN chown -R www-data:www-data /var/www/newznab && \
    chmod -R 755 /var/www/newznab && \
    chmod -R 775 /var/www/newznab/storage /var/www/newznab/bootstrap/cache

# Production stage
FROM php:8.4-fpm-alpine

# Install runtime dependencies only
RUN apk add --no-cache \
    curl \
    libzip \
    libpng \
    libjpeg-turbo \
    freetype \
    icu-libs \
    unrar \
    p7zip \
    ffmpeg \
    mediainfo \
    git

WORKDIR /var/www/newznab

# Copy from builder
COPY --from=php-base /var/www/newznab /var/www/newznab
COPY --from=php-base /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=php-base /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

# Copy PHP configuration
COPY php.ini /usr/local/etc/php/
COPY www.conf /usr/local/etc/php-fpm.d/

# Create non-root user
RUN addgroup -g 1000 laravel && \
    adduser -D -u 1000 -G laravel laravel && \
    chown -R laravel:laravel /var/www/newznab

USER laravel

EXPOSE 9000

CMD ["php-fpm"]
