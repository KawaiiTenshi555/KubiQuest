# Build context: root of the repository
# docker build -f docker/api/Dockerfile -t ghcr.io/kubiquest/api:latest .

# ─────────────────────────────────────────
# Stage 1: Install PHP dependencies
# ─────────────────────────────────────────
FROM composer:2.7 AS composer

WORKDIR /app

COPY api/composer.json api/composer.lock* ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --optimize-autoloader \
    --prefer-dist

# ─────────────────────────────────────────
# Stage 2: Runtime image
# ─────────────────────────────────────────
FROM php:8.2-fpm-alpine AS runner

RUN apk add --no-cache \
        nginx \
        supervisor \
        libpng-dev \
        libzip-dev \
        oniguruma-dev \
    && docker-php-ext-install \
        pdo_mysql \
        mbstring \
        zip \
        bcmath \
        opcache \
    && rm -rf /var/cache/apk/*

WORKDIR /var/www/html

# Copy vendor from composer stage
COPY --from=composer /app/vendor ./vendor

# Copy application code
COPY api/ .

# Copy config files
COPY docker/api/nginx.conf    /etc/nginx/http.d/default.conf
COPY docker/api/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/api/php.ini       /usr/local/etc/php/conf.d/custom.ini

# Set permissions
RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Generate app key if not set, cache config
RUN php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
