#!/bin/bash
set -e

echo "🚀 Starting Newznab-tmux All-in-One Container..."

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
# Configure and start services with Supervisor
# ============================================================================
echo "🔧 Starting services..."

# Start supervisord in foreground
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
