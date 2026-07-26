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
        sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|g" /var/www/newznab/.env
        sed -i "s|MEILISEARCH_KEY=.*|MEILISEARCH_KEY=$MEILISEARCH_KEY|g" /var/www/newznab/.env
        sed -i "s|APP_KEY=|APP_KEY=$APP_KEY|g" /var/www/newznab/.env
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
