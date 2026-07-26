#!/bin/bash
# Diagnostic script to verify system configuration before supervisor starts services

echo "🔍 Running pre-startup diagnostics..."
echo ""

# Test PHP-FPM config
echo "Testing PHP-FPM..."
/usr/sbin/php-fpm8.4 -t 2>&1 | grep -q successful
if [ $? -eq 0 ]; then
    echo "  ✓ PHP-FPM config test passed"
else
    echo "  ✗ PHP-FPM config test failed"
    /usr/sbin/php-fpm8.4 -t 2>&1
fi
echo ""

# Test Nginx config
echo "Testing Nginx..."
/usr/sbin/nginx -t 2>&1 | grep -q successful
if [ $? -eq 0 ]; then
    echo "  ✓ Nginx config test passed"
else
    echo "  ✗ Nginx config test failed"
    /usr/sbin/nginx -t 2>&1
fi
echo ""

# Verify required binaries exist
echo "Checking required services..."
[ -x /usr/sbin/mysqld ] && echo "  ✓ MariaDB binary found" || echo "  ✗ MariaDB binary missing"
[ -x /usr/bin/redis-server ] && echo "  ✓ Redis binary found" || echo "  ✗ Redis binary missing"
[ -x /usr/local/bin/meilisearch ] && echo "  ✓ Meilisearch binary found" || echo "  ✗ Meilisearch binary missing"
[ -x /usr/sbin/php-fpm8.4 ] && echo "  ✓ PHP-FPM binary found" || echo "  ✗ PHP-FPM binary missing"
[ -x /usr/sbin/nginx ] && echo "  ✓ Nginx binary found" || echo "  ✗ Nginx binary missing"
echo ""

# Verify directories exist
echo "Checking required directories..."
[ -d /var/www/newznab ] && echo "  ✓ Application directory found" || echo "  ✗ Application directory missing"
[ -d /data/mysql ] && echo "  ✓ MariaDB data directory found" || echo "  ✗ MariaDB data directory missing"
[ -d /data/redis ] && echo "  ✓ Redis data directory found" || echo "  ✗ Redis data directory missing"
[ -d /config ] && echo "  ✓ Config directory found" || echo "  ✗ Config directory missing"
echo ""

echo "🔍 Diagnostics complete"
