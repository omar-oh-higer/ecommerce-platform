# Laravel core-api — PHP-FPM image.
# Multi-arch: works on Apple Silicon (arm64), Intel Macs and Windows/Linux (amd64).
FROM php:8.4-fpm

# Helper that installs PHP extensions with all their system libraries.
COPY --from=mlocati/php-extension-installer:2.7 /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions pdo_mysql bcmath intl zip opcache pcntl \
    && apt-get update \
    && apt-get install -y --no-install-recommends git unzip default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# gRPC client for the inventory service (requirement 2).
# Compiled from source: this layer takes 10–20 minutes the first time, then it is cached.
# Only 2 parallel compile jobs: compiling gRPC with every core can use more memory than
# Docker Desktop allows and crash it.
RUN IPE_PROCESSOR_COUNT=2 install-php-extensions grpc

# Image handling (product image tests create fake images with GD).
# Kept after grpc so adding it does not rebuild the slow grpc layer.
RUN install-php-extensions gd

COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer

COPY docker/php.ini /usr/local/etc/php/conf.d/zz-app.ini
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html

# The source code is mounted from the host by docker-compose (see /docker-compose.yml),
# so a `git pull` is visible immediately without rebuilding the image.

EXPOSE 9000
ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]
