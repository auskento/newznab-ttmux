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
# Ensure all required directories and permissions exist EARLY
# ============================================================================
mkdir -p /config /data/mysql /data/redis /data/meilisearch /data/logs
mkdir -p /config/bootstrap-cache /config/storage/logs /config/storage/app /config/storage/framework/cache /config/storage/framework/sessions /config/storage/framework/views
chmod 775 /config /config/bootstrap-cache
chmod -R 775 /config/storage
chown -R www-data:www-data /config /config/storage /config/bootstrap-cache

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
CREDENTIALS_FILE="/config/.env.generated"

if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "🔐 First run detected - generating credentials..."
    echo ""

    # Generate secure random passwords
    DB_PASSWORD=$(openssl rand -base64 16 | tr -d '\n=')
    ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d '\n=')
    MEILISEARCH_KEY=$(openssl rand -base64 32 | tr -d '\n=')
    MEILISEARCH_MASTER_KEY=$(openssl rand -base64 32 | tr -d '\n=')
    APP_KEY=$(openssl rand -base64 32 | tr -d '\n=')

    # Update .env file with generated credentials
    # Create /config/.env from .env.example if it doesn't exist
    if [ ! -f "/config/.env" ] && [ -f "/var/www/newznab/.env.example" ]; then
        cp /var/www/newznab/.env.example /config/.env
    fi

    if [ -f "/config/.env" ]; then
        # Use sed to update or add values
        sed -i "s|^DB_HOST=.*|DB_HOST=127.0.0.1|" /config/.env
        sed -i "s|^DB_USERNAME=.*|DB_USERNAME=newznab|" /config/.env
        sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" /config/.env
        sed -i "s|^MEILISEARCH_KEY=.*|MEILISEARCH_KEY=$MEILISEARCH_KEY|" /config/.env
        sed -i "s|^APP_KEY=\(.*\)|APP_KEY=$APP_KEY|" /config/.env

        # Ensure values exist if they don't
        grep -q "^DB_HOST=" /config/.env || echo "DB_HOST=127.0.0.1" >> /config/.env
        grep -q "^DB_USERNAME=" /config/.env || echo "DB_USERNAME=newznab" >> /config/.env
        grep -q "^DB_PASSWORD=" /config/.env || echo "DB_PASSWORD=$DB_PASSWORD" >> /config/.env
        grep -q "^MEILISEARCH_KEY=" /config/.env || echo "MEILISEARCH_KEY=$MEILISEARCH_KEY" >> /config/.env
        grep -q "^APP_KEY=" /config/.env || echo "APP_KEY=$APP_KEY" >> /config/.env
    fi

    # Mark credentials as generated
    cat > "$CREDENTIALS_FILE" << EOF
DB_PASSWORD=$DB_PASSWORD
ADMIN_PASSWORD=$ADMIN_PASSWORD
MEILISEARCH_KEY=$MEILISEARCH_KEY
MEILISEARCH_MASTER_KEY=$MEILISEARCH_MASTER_KEY
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
    echo "║  🗝️  Meilisearch Master Key:                               ║"
    echo "║     $MEILISEARCH_MASTER_KEY ║"
    echo "║                                                            ║"
    echo "║  🔑 Laravel APP_KEY:                                       ║"
    echo "║     $APP_KEY ║"
    echo "║                                                            ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║  ⚠️  IMPORTANT: Save these credentials securely!            ║"
    echo "║  They are stored in: /config/.env.generated                ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
else
    echo "✓ Using existing credentials"
    source "$CREDENTIALS_FILE"
    echo "  Credentials generated at: $GENERATED_AT"
    echo ""
    # Ensure MEILISEARCH_MASTER_KEY is set from credentials
    if [ -z "$MEILISEARCH_MASTER_KEY" ] && grep -q "MEILISEARCH_MASTER_KEY=" "$CREDENTIALS_FILE"; then
        MEILISEARCH_MASTER_KEY=$(grep "MEILISEARCH_MASTER_KEY=" "$CREDENTIALS_FILE" | cut -d= -f2)
    fi
fi

# Export environment variable for supervisord
export MEILISEARCH_MASTER_KEY

# ============================================================================
# Database Setup on First Run
# ============================================================================
SETUP_FILE="/config/.setup-complete"

# Check if setup is needed
# Primary check: Do database tables exist?
# This is checked FIRST because migrations might fail even if setup marker exists
SETUP_NEEDED=0

# Wait a bit for database to be fully ready
sleep 5

# Check if settings table exists (indicates successful prior setup)
if mysql -u newznab -p"$DB_PASSWORD" -h 127.0.0.1 nntmux -e "SELECT 1 FROM settings LIMIT 1" 2>/dev/null; then
    echo "✓ Database tables exist - skipping setup"
else
    echo "⚙️  Database tables missing - running setup..."
    SETUP_NEEDED=1
fi

if [ $SETUP_NEEDED -eq 1 ]; then
    echo "⚙️  Setting up database and application..."
    echo ""

    # Ensure www-data user exists
    if ! id www-data &>/dev/null; then
        useradd -r -s /bin/false www-data
        echo "  Created www-data user"
    fi

    # Test PHP configuration
    echo "  🧪 PHP Configuration Test:"
    echo "     Version: $(/usr/bin/php -v 2>&1 | head -1)"
    FPM_TEST=$(/usr/sbin/php-fpm8.4 -t 2>&1)
    if echo "$FPM_TEST" | grep -qi 'successful'; then
        echo "     FPM Config: OK"
    else
        echo "     FPM Config: $FPM_TEST"
    fi
    echo "     Loaded Extensions: $(/usr/bin/php -m 2>&1 | wc -l) extensions"
    echo "     Key Settings:"
    /usr/bin/php -r "echo '       memory_limit: ' . ini_get('memory_limit') . PHP_EOL; echo '       max_execution_time: ' . ini_get('max_execution_time') . PHP_EOL; echo '       upload_max_filesize: ' . ini_get('upload_max_filesize') . PHP_EOL; echo '       post_max_size: ' . ini_get('post_max_size') . PHP_EOL;" 2>&1 || echo "     PHP config read failed"

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

    # Run diagnostics before starting services
    if [ -f "/docker-diagnostic.sh" ]; then
        echo "  Running pre-startup diagnostics..."
        bash /docker-diagnostic.sh 2>&1 | sed 's/^/  /'
        echo ""
    fi

    # Ensure all data directories exist with correct permissions
    mkdir -p /data/redis /data/mysql /data/meilisearch /data/logs
    chown -R mysql:mysql /data/mysql
    chown -R redis:redis /data/redis
    mkdir -p /var/run/php
    chmod 755 /var/run/php

    # Start services temporarily for setup
    /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &
    SUPERVISOR_PID=$!

    # Wait for MariaDB to be ready (connect as root via socket first)
    echo "  ⏳ Waiting for MariaDB to be ready..."
    for i in {1..60}; do
        if mysql -u root -e "SELECT 1" 2>/dev/null; then
            echo "  ✓ MariaDB is ready"
            break
        fi
        if [ $i -eq 60 ]; then
            echo "  ✗ MariaDB failed to start after 60 seconds"
            kill $SUPERVISOR_PID 2>/dev/null || true
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

    # Test database connection as newznab user (with retries)
    echo "  Testing database connection as newznab user..."
    DB_READY=0
    for i in {1..10}; do
        if mysql -u newznab -p"$DB_PASSWORD" -h 127.0.0.1 nntmux -e "SELECT 1" 2>/dev/null; then
            echo "  ✓ Database connection successful on attempt $i"
            DB_READY=1
            break
        fi
        if [ $i -lt 10 ]; then
            echo "  Attempt $i failed, retrying..."
            sleep 1
        fi
    done

    if [ $DB_READY -ne 1 ]; then
        echo "  ✗ Database connection failed after 10 attempts"
        echo "  Checking if database user exists..."
        if mysql -u root -e "SELECT USER FROM mysql.user WHERE User='newznab'" 2>/dev/null | grep -q newznab; then
            echo "  User 'newznab' exists in database"
        else
            echo "  User 'newznab' NOT found in database"
        fi
        kill $SUPERVISOR_PID 2>/dev/null || true
        exit 1
    fi

    echo ""
    echo "  Verifying .env configuration..."
    if [ -f "/config/.env" ]; then
        echo "  Database config in .env:"
        grep "^DB_" /config/.env 2>/dev/null || echo "    No DB_ variables found"
    else
        echo "  ⚠️  .env file not found at /config/.env"
    fi

    # Verify Laravel .env is readable from app directory
    if [ ! -L "/var/www/newznab/.env" ]; then
        echo "  ⚠️  Symlink /var/www/newznab/.env does not exist"
        echo "  Creating symlink..."
        ln -sf /config/.env /var/www/newznab/.env
    fi

    echo ""
    echo "  Running database migrations..."
    cd /var/www/newznab

    # Clear config cache before migrations to prevent DB access during bootstrap
    rm -f /config/bootstrap-cache/config.php /config/bootstrap-cache/services.php 2>/dev/null || true

    # Create a minimal settings table stub so Laravel bootstrap can load config
    # This prevents "table doesn't exist" errors during migration bootstrap
    mysql -u newznab -p"$DB_PASSWORD" -h 127.0.0.1 nntmux << 'EOF' 2>/dev/null || true
CREATE TABLE IF NOT EXISTS settings (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  value LONGTEXT COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (id),
  UNIQUE KEY settings_name_unique (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
EOF

    # Run migrations with no-interaction to prevent hangs
    if php artisan migrate --force --no-interaction 2>&1 | tee /tmp/migrate.log; then
        echo "  ✓ Migrations completed successfully"
    else
        MIGRATE_EXIT=$?
        echo "  ⚠️  Migration exit code: $MIGRATE_EXIT"
        echo "  Database connection test:"
        mysql -u newznab -p"$DB_PASSWORD" -h 127.0.0.1 nntmux -e "SHOW TABLES" 2>/dev/null || echo "    Connection failed"
        echo "  Last 20 lines of migration output:"
        tail -20 /tmp/migrate.log
    fi

    # Verify tables were created
    echo "  Checking if tables were created..."
    TABLES_EXIST=0
    if mysql -u newznab -p"$DB_PASSWORD" -h 127.0.0.1 nntmux -e "SHOW TABLES" 2>/dev/null | grep -q settings; then
        echo "  ✓ Settings table exists - setup successful"
        TABLES_EXIST=1
    else
        echo "  ⚠️  Settings table not found - migrations failed or incomplete"
        echo "  Tables in database:"
        mysql -u newznab -p"$DB_PASSWORD" -h 127.0.0.1 nntmux -e "SHOW TABLES" 2>/dev/null || echo "    (could not query tables)"
    fi

    # Only run seeding if migrations succeeded
    if [ $TABLES_EXIST -eq 1 ]; then
        echo "  Seeding initial data..."
        cd /var/www/newznab && php artisan db:seed --force 2>&1 | head -20 || true

        # Mark setup as complete ONLY if migrations succeeded
        touch "$SETUP_FILE"
        echo "  ✓ Setup complete"
        echo ""
        echo "  ℹ️  Admin user setup:"
        echo "     Create your first admin account through the web interface"
        echo "     at http://localhost:8080 during initial setup"
    else
        echo "  ✗ Setup incomplete - tables not created"
        echo "  Will retry on next container start"
    fi
    echo ""

    # Stop supervisord gracefully
    echo "  Stopping temporary supervisor..."
    kill $SUPERVISOR_PID 2>/dev/null || true

    # Wait for supervisor to gracefully shut down its children
    # This gives MariaDB, Redis, etc. time to close their files properly
    sleep 15

    # Only force-kill any remaining processes that didn't stop gracefully
    pkill -9 supervisord 2>/dev/null || true
    pkill -9 mariadb 2>/dev/null || true
    pkill -9 redis-server 2>/dev/null || true
    pkill -9 meilisearch 2>/dev/null || true
    pkill -9 php-fpm 2>/dev/null || true
    pkill -9 nginx 2>/dev/null || true

    # Clean up stale MariaDB lock files that might prevent restart
    rm -f /data/mysql/ibdata1.lock 2>/dev/null || true
    rm -f /data/mysql/aria_log_control.lock 2>/dev/null || true
    rm -f /run/mysqld/mysqld.pid 2>/dev/null || true
    rm -f /run/mysqld/mysqld.sock.lock 2>/dev/null || true

    # Wait for all sockets and ports to fully release
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
