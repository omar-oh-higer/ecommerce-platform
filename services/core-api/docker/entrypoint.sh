#!/bin/sh
# Prepares the Laravel app every time the container starts, then runs the main command (php-fpm).
# Every step is safe to repeat: it only does work that is still missing.
set -e

cd /var/www/html

echo "[core-api] Preparing the application..."

# 1. PHP dependencies (first run, or after composer.lock changed).
if [ ! -f vendor/autoload.php ] || [ composer.lock -nt vendor/autoload.php ]; then
    echo "[core-api] Installing Composer dependencies (first run takes a few minutes)..."
    composer install --no-interaction --prefer-dist --no-progress
    touch vendor/autoload.php
fi

# 2. Environment file.
if [ ! -f .env ]; then
    echo "[core-api] Creating .env from .env.example"
    cp .env.example .env
fi

# Config may have been cached on the host; always read the live environment in Docker.
php artisan config:clear >/dev/null

# 3. Secrets: generated once and kept in .env, so tokens survive restarts.
if ! grep -q '^APP_KEY=base64:' .env; then
    php artisan key:generate --force
fi
if ! grep -q '^JWT_SECRET=.\+' .env; then
    php artisan jwt:secret --force
fi

# 4. Writable folders.
mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache
chmod -R ug+rwX storage bootstrap/cache 2>/dev/null || true

# 5. Wait for MySQL, then migrate and seed (the seeder can run many times).
echo "[core-api] Waiting for the database at ${DB_HOST}:${DB_PORT}..."
until php -r "new PDO('mysql:host=${DB_HOST};port=${DB_PORT}', '${DB_USERNAME}', '${DB_PASSWORD}');" >/dev/null 2>&1; do
    sleep 2
done

php artisan migrate --force
php artisan db:seed --force

# 6. Public link for uploaded files (product images).
php artisan storage:link >/dev/null 2>&1 || true

echo "[core-api] Ready: http://localhost:${APP_PORT:-8000}/api/v1"

exec "$@"
