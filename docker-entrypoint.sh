#!/bin/bash
set -e

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     🚀 Newznab-tmux All-in-One Container Starting...      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Wait for base system to be ready
sleep 2

# ============================================================================
# Initialize MariaDB if needed
# ============================================================================
echo "📦 Initializing MariaDB..."
if [ ! -d "/data/mysql/mysql" ]; then
    echo "  Creating MariaDB data directory..."
    mysql_install_db --user=mysql --datadir=/data/mysql --skip-test-db
    echo "  Marking first run..."
    touch /data/mysql/.fresh-install
fi

# ============================================================================
# Generate credentials and configuration on first run
# ============================================================================
CREDENTIALS_FILE="/var/www/newznab/.env.generated"

if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "🔐 First run detected - generating credentials..."
    echo ""

    # Generate secure random passwords
    DB_PASSWORD=$(openssl rand -base64 16 | tr -d '\n=')
    ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d '\n=')
    MEILISEARCH_KEY=$(openssl rand -base64 32 | tr -d '\n=')
    APP_KEY=$(openssl rand -base64 32 | tr -d '\n=')

    # Update .env file with generated credentials
    if [ -f "/var/www/newznab/.env" ]; then
        # Use grep -v to remove old values, then append new ones
        grep -v "^DB_HOST=" /var/www/newznab/.env > /tmp/.env.tmp
        grep -v "^DB_USERNAME=" /tmp/.env.tmp > /var/www/newznab/.env
        grep -v "^DB_PASSWORD=" /var/www/newznab/.env > /tmp/.env.tmp
        grep -v "^MEILISEARCH_KEY=" /tmp/.env.tmp > /var/www/newznab/.env
        grep -v "^APP_KEY=" /var/www/newznab/.env > /tmp/.env.tmp
        mv /tmp/.env.tmp /var/www/newznab/.env

        # Append new values
        echo "" >> /var/www/newznab/.env
        echo "DB_HOST=127.0.0.1" >> /var/www/newznab/.env
        echo "DB_USERNAME=newznab" >> /var/www/newznab/.env
        echo "DB_PASSWORD=$DB_PASSWORD" >> /var/www/newznab/.env
        echo "MEILISEARCH_KEY=$MEILISEARCH_KEY" >> /var/www/newznab/.env
        echo "APP_KEY=$APP_KEY" >> /var/www/newznab/.env
    fi

    # Mark credentials as generated
    cat > "$CREDENTIALS_FILE" << EOF
DB_PASSWORD=$DB_PASSWORD
ADMIN_PASSWORD=$ADMIN_PASSWORD
MEILISEARCH_KEY=$MEILISEARCH_KEY
APP_KEY=$APP_KEY
GENERATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

    # Display credentials prominently
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║               ⚠️  CREDENTIALS GENERATED ⚠️                 ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║                                                            ║"
    echo "║  📧 Admin Account:                                         ║"
    echo "║     Username: admin                                        ║"
    echo "║     Password: $ADMIN_PASSWORD                           ║"
    echo "║                                                            ║"
    echo "║  🗄️  Database:                                             ║"
    echo "║     Username: newznab                                      ║"
    echo "║     Password: $DB_PASSWORD                   ║"
    echo "║     Host: 127.0.0.1:3306                                   ║"
    echo "║                                                            ║"
    echo "║  🔍 Meilisearch API Key:                                   ║"
    echo "║     $MEILISEARCH_KEY ║"
    echo "║                                                            ║"
    echo "║  🔑 Laravel APP_KEY:                                       ║"
    echo "║     $APP_KEY ║"
    echo "║                                                            ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║  ⚠️  IMPORTANT: Save these credentials securely!            ║"
    echo "║  They are stored in: /var/www/newznab/.env.generated       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
else
    echo "✓ Using existing credentials"
    source "$CREDENTIALS_FILE"
    echo "  Credentials generated at: $GENERATED_AT"
    echo ""
fi

# ============================================================================
# Database Setup on First Run
# ============================================================================
SETUP_FILE="/var/www/newznab/.setup-complete"

if [ ! -f "$SETUP_FILE" ]; then
    echo "⚙️  Setting up database and application (first run only)..."
    echo ""

    # Ensure www-data user exists
    if ! id www-data &>/dev/null; then
        useradd -r -s /bin/false www-data
        echo "  Created www-data user"
    fi

    # Test PHP configuration
    echo "  🧪 PHP Configuration Test:"
    echo "     Version: $(/usr/bin/php -v | head -1)"
    echo "     FPM Config: $(/usr/sbin/php-fpm8.4 -t 2>&1 | grep -i 'success\|error' || echo 'OK')"
    echo "     Loaded Extensions: $(/usr/bin/php -m | wc -l) extensions"
    echo "     Key Settings:"
    /usr/bin/php -r "echo '       memory_limit: ' . ini_get('memory_limit') . PHP_EOL; echo '       max_execution_time: ' . ini_get('max_execution_time') . PHP_EOL; echo '       upload_max_filesize: ' . ini_get('upload_max_filesize') . PHP_EOL; echo '       post_max_size: ' . ini_get('post_max_size') . PHP_EOL;"

    # Fix permissions for PHP-FPM
    echo "  Verifying system permissions..."
    mkdir -p /run/php
    chown -R www-data:www-data /run/php
    chmod 755 /run/php
    mkdir -p /var/log
    touch /var/log/php-errors.log
    chown www-data:www-data /var/log/php-errors.log
    chmod 664 /var/log/php-errors.log
    echo ""

    # Start services temporarily for setup
    /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &
    SUPERVISOR_PID=$!

    # Wait for MariaDB to be ready (connect as root via socket first)
    echo "  ⏳ Waiting for MariaDB to be ready..."
    for i in {1..30}; do
        if mysql -u root -e "SELECT 1" 2>/dev/null; then
            echo "  ✓ MariaDB is ready"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "  ✗ MariaDB failed to start"
            kill $SUPERVISOR_PID
            exit 1
        fi
        sleep 1
    done

    # Create database and user (only on first run)
    if [ -f "/data/mysql/.fresh-install" ]; then
        echo "  Creating database and user..."
        mysql -u root -e "CREATE DATABASE IF NOT EXISTS nntmux CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        mysql -u root -e "CREATE USER IF NOT EXISTS 'newznab'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
        mysql -u root -e "GRANT ALL PRIVILEGES ON nntmux.* TO 'newznab'@'localhost';"
        mysql -u root -e "CREATE USER IF NOT EXISTS 'newznab'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';"
        mysql -u root -e "GRANT ALL PRIVILEGES ON nntmux.* TO 'newznab'@'127.0.0.1';"
        mysql -u root -e "FLUSH PRIVILEGES;"
        rm /data/mysql/.fresh-install
    fi

    echo ""
    echo "  Running database migrations..."
    cd /var/www/newznab && php artisan migrate --force --quiet

    echo "  Seeding initial data..."
    cd /var/www/newznab && php artisan db:seed --force --quiet

    echo "  Creating admin user..."
    cd /var/www/newznab && php artisan nntmux:create-admin \
        --name="Administrator" \
        --email="admin@localhost" \
        --username="admin" \
        --password="$ADMIN_PASSWORD" \
        --quiet 2>/dev/null || true

    # Mark setup as complete
    touch "$SETUP_FILE"

    echo "  ✓ Setup complete"
    echo ""

    # Stop supervisord and let it restart fresh
    kill $SUPERVISOR_PID
    sleep 5
fi

# ============================================================================
# Configure and start services with Supervisor
# ============================================================================
echo "🔧 Starting services..."
echo "   ✓ PHP-FPM"
echo "   ✓ Nginx (port 80)"
echo "   ✓ MariaDB (localhost:3306)"
echo "   ✓ Redis (localhost:6379)"
echo "   ✓ Meilisearch (localhost:7700)"
echo "   ✓ Supervisor (background jobs)"
echo ""

# Start supervisord in foreground
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
