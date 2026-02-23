# ─────────────────────────────────────────
# Stage 1: Install PHP dependencies
# ─────────────────────────────────────────
FROM composer:2.7 AS composer

WORKDIR /app

# Install dependencies without dev packages
COPY composer.json composer.lock ./
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

# Install system dependencies and PHP extensions
RUN apk add --no-cache \
        nginx \
        supervisor \
        libpng-dev \
        libzip-dev \
        oniguruma-dev \
        icu-dev \
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
COPY . .

# Copy configuration files
COPY docker/api/nginx.conf /etc/nginx/http.d/default.conf
COPY docker/api/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/api/php.ini /usr/local/etc/php/conf.d/custom.ini

# Set permissions
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Optimize Laravel
RUN php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache

EXPOSE 80

# Run supervisor (manages nginx + php-fpm)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
