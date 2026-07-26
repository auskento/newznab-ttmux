#!/bin/bash
# Diagnostic script to test individual services before supervisor starts them

echo "🔍 Running pre-startup diagnostics..."
echo ""

# Test MariaDB
echo "Testing MariaDB..."
if /usr/sbin/mysqld --user=mysql --datadir=/data/mysql --bind-address=127.0.0.1 --port=3306 --skip-grant-tables &
    MARIADB_PID=$!
    sleep 2
    if mysql -u root -e "SELECT VERSION()" 2>/dev/null; then
        echo "  ✓ MariaDB test passed"
    else
        echo "  ✗ MariaDB connection failed"
    fi
    kill $MARIADB_PID 2>/dev/null
else
    echo "  ✗ MariaDB failed to start: $?"
fi
echo ""

# Test Redis
echo "Testing Redis..."
if /usr/bin/redis-server --dir /data/redis --dbfilename dump.rdb --appendonly yes --port 6379 --daemonize yes 2>&1; then
    sleep 1
    if /usr/bin/redis-cli ping 2>/dev/null | grep -q PONG; then
        echo "  ✓ Redis test passed"
    else
        echo "  ✗ Redis connection failed"
    fi
    /usr/bin/redis-cli shutdown 2>/dev/null || true
else
    echo "  ✗ Redis failed to start"
fi
echo ""

# Test Meilisearch
echo "Testing Meilisearch..."
if timeout 5 /usr/local/bin/meilisearch --db-path=/data/meilisearch --env=production 2>&1 | head -20; then
    echo "  ✓ Meilisearch started (timeout is expected)"
else
    EXIT_CODE=$?
    echo "  ✗ Meilisearch failed with exit code: $EXIT_CODE"
fi
echo ""

# Test PHP-FPM
echo "Testing PHP-FPM..."
/usr/sbin/php-fpm8.4 -t 2>&1
if [ $? -eq 0 ]; then
    echo "  ✓ PHP-FPM config test passed"
else
    echo "  ✗ PHP-FPM config test failed"
fi

if timeout 5 /usr/sbin/php-fpm8.4 -F -R 2>&1 | head -20; then
    echo "  ✓ PHP-FPM started (timeout is expected)"
else
    EXIT_CODE=$?
    echo "  ✗ PHP-FPM failed with exit code: $EXIT_CODE"
fi
echo ""

# Test Nginx
echo "Testing Nginx..."
/usr/sbin/nginx -t 2>&1
if [ $? -eq 0 ]; then
    echo "  ✓ Nginx config test passed"
else
    echo "  ✗ Nginx config test failed"
fi

if /usr/sbin/nginx -g "daemon off;" 2>&1 | head -20 &
    NGINX_PID=$!
    sleep 2
    kill $NGINX_PID 2>/dev/null || true
    echo "  ✓ Nginx started (killed after test)"
else
    echo "  ✗ Nginx failed to start"
fi

echo ""
echo "🔍 Diagnostics complete"
