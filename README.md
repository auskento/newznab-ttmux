# Newznab-tmux All-in-One Docker Setup

This is a complete, self-contained Docker deployment for [Newznab-tmux](https://github.com/NNTmux/newznab-tmux). A single container includes everything needed: PHP-FPM, Nginx, MariaDB, Redis, Meilisearch, and Supervisor for background jobs. Perfect for Unraid or any Docker host.

## Features

- **✅ All-in-one container** - single service with all components
- **✅ Self-contained** - no external dependencies, no multi-container orchestration
- **✅ Complete Laravel stack** with all required PHP extensions
- **✅ Built-in database** - MariaDB running inside container
- **✅ Redis cache & queue** - included and managed by Supervisor
- **✅ Full-text search** - Meilisearch integrated
- **✅ Background job processing** - Supervisor manages workers & scheduler
- **✅ Web server** - Nginx with security headers
- **✅ Simple deployment** - Unraid template + Docker Compose
- **✅ Persistent storage** - All data persisted to host volumes

## Prerequisites

- Unraid 6.9 or later
- Docker/Docker Compose capability (default on Unraid)
- Minimum 16GB RAM recommended
- 100GB+ storage for indexing data
- Network connectivity to Usenet providers

## Installation on Unraid

### Method 1: Using the Unraid Template

1. **Add Template to Unraid:**
   - In Unraid WebUI, go to **Docker** tab
   - Click **Add Container**
   - Select **Template** (if available) or manually enter settings
   - Use the `newznab-tmux.xml` file from this repository

2. **Configure Container:**
   - Set **Repository** to the pre-built image (or build locally)
   - Adjust port binding: 8080 → 80 (or your preferred port)
   - Create appdata directory: `/mnt/user/appdata/newznab`
   - All services (DB, Redis, Meilisearch) use this single appdata folder

3. **Set Environment Variables (Optional):**
   - `PHP_MEMORY_LIMIT`: Increase for large indexes (default 512M)
   - `MEILISEARCH_KEY`: Secure your search API (auto-generated if not set)
   - `APP_URL`: Your server URL (optional)

4. **Start Container:**
   - Click **Add** or **Start**
   - Wait 30-60 seconds for all services to initialize
   - Monitor logs via Unraid WebUI

### Method 2: Manual Docker Compose

1. **Clone or download this repository:**
   ```bash
   cd /mnt/user/appdata
   git clone <this-repo> newznab-tmux
   cd newznab-tmux
   ```

2. **Setup Environment (Optional):**
   ```bash
   mkdir -p config
   cp .env.example config/.env
   # Edit config/.env to customize (most settings work with defaults)
   nano config/.env
   ```

3. **Build and Start:**
   ```bash
   docker-compose up -d --build
   ```

4. **Wait for Initialization:**
   - Services take 30-60 seconds to fully start
   - Monitor with: `docker-compose logs -f`
   - Wait for "MariaDB initialized" message

5. **Initialize Application (First Run Only):**
   ```bash
   docker-compose exec newznab php artisan migrate --force
   docker-compose exec newznab php artisan db:seed
   ```

6. **Access Web Interface:**
   - Navigate to `http://localhost:8080` (or your host IP:8080)
   - Default credentials: admin / admin (CHANGE IMMEDIATELY)

## Directory Structure

```
/mnt/user/appdata/newznab/
├── storage/              # Application storage (logs, cache, uploads)
├── config/               # Configuration files
│   └── .env             # Environment configuration
├── nzbs/                # NZB files directory
├── mysql/               # MariaDB data
├── redis/               # Redis data
└── meilisearch/         # Meilisearch index data

# Repository structure (for building):
newznab-tmux-docker/
├── Dockerfile           # All-in-one container build
├── docker-compose.yml   # Single service definition
├── docker-entrypoint.sh # Service initialization script
├── supervisord.conf     # Process management config
├── nginx.conf          # Web server configuration
├── php.ini             # PHP settings
├── www.conf            # PHP-FPM configuration
├── newznab-tmux.xml    # Unraid template
└── README.md           # This file
```

## Configuration

### Environment Variables (config/.env)

Most settings have sensible defaults and work out-of-the-box. Only customize if needed:

| Variable | Description | Default | Notes |
|----------|-------------|---------|-------|
| `PHP_MEMORY_LIMIT` | PHP memory allocation | 512M | Increase for large indexes |
| `PHP_MAX_EXECUTION_TIME` | PHP script timeout | 300s | Leave as-is for most use cases |
| `MEILISEARCH_KEY` | Search API key | changeme | Change for security |
| `APP_URL` | Your server URL | (unset) | Optional, auto-detected usually |

### Internal Services

All services run inside the container and communicate via localhost:

- **MariaDB**: localhost:3306 (user: newznab)
- **Redis**: localhost:6379 (no auth)
- **Meilisearch**: localhost:7700
- **PHP-FPM**: localhost:9000 (internal only)
- **Nginx**: 0.0.0.0:80 (exposed to host)
- **Supervisor**: localhost:9001 (internal only)

No external services needed. Database, cache, and search are all included.

## Volumes and Storage

All persistent data is stored in `/mnt/user/appdata/newznab/`:

| Directory | Purpose | Size | Notes |
|-----------|---------|------|-------|
| `storage/` | Laravel logs, uploads, cache | Small | Application data |
| `config/` | Configuration files (.env) | ~1KB | Mount as read-only |
| `nzbs/` | Downloaded NZB files | Large | Grows with indexing |
| `mysql/` | MariaDB database files | Large | Critical - backup regularly |
| `redis/` | Redis persistence | Small | Caching only, can be lost |
| `meilisearch/` | Search indexes | Large | Rebuilds if lost |

### Storage Recommendations

- **Pool placement**: Store `/mnt/user/appdata/newznab` on fast pool (SSD preferred)
- **Space allocation**: 
  - Database: 50-100GB depending on Usenet history
  - Indexes: 10-50GB for Meilisearch
  - NZBs: 1-10GB per million releases
- **Backup strategy**: Regular database backups critical
- **Cache safety**: Redis and Meilisearch data can be regenerated

## Initial Setup

### First Run (After Starting Container)

1. **Wait for initialization** (30-60 seconds):
   ```bash
   docker-compose logs -f
   # Wait for: "MariaDB initialized" and all services showing "started"
   ```

2. **Run database migrations** (first time only):
   ```bash
   docker-compose exec newznab php artisan migrate --force
   ```

3. **Optional: Seed demo data**:
   ```bash
   docker-compose exec newznab php artisan db:seed
   ```

4. **Access web interface:**
   - URL: `http://localhost:8080` (or your Unraid IP:8080)
   - Default username: `admin`
   - Default password: `admin`

### First Run Checklist

- [ ] Container started successfully
- [ ] All services initialized (check logs)
- [ ] Database migrations completed
- [ ] Can access web interface at port 8080
- [ ] **CHANGE DEFAULT ADMIN PASSWORD IMMEDIATELY**
- [ ] Configure Usenet servers in Settings
- [ ] Add API keys for TMDB/OMDB/etc (optional but recommended)
- [ ] Configure backup strategy for database

## Management

### Viewing Logs

```bash
# All container logs
docker-compose logs -f

# Specific service logs (inside container)
docker-compose logs -f | grep nginx
docker-compose logs -f | grep mysql
docker-compose logs -f | grep redis
docker-compose logs -f | grep meilisearch

# Supervisor process logs
docker-compose exec newznab tail -f /var/log/supervisor/supervisord.log
docker-compose exec newznab ls -la /var/log/supervisor/
```

### Database Maintenance

```bash
# Connect to MySQL inside container
docker-compose exec newznab mysql -u newznab -p newznab

# Backup database
docker-compose exec newznab mysqldump -u newznab -p newznab > backup.sql

# Restore database
docker-compose exec newznab mysql -u newznab -p newznab < backup.sql

# Quick database status
docker-compose exec newznab mysql -u newznab -p newznab -e "SHOW DATABASES; SHOW TABLES;"
```

### Monitor Queue Jobs

```bash
# View failed jobs
docker-compose exec newznab php artisan queue:failed

# Retry failed jobs
docker-compose exec newznab php artisan queue:retry all

# Monitor queue status
docker-compose exec newznab php artisan queue:work --max-jobs=1 --max-time=1
```

### Container Management

```bash
# Stop container (keeps data)
docker-compose down

# Stop and remove volumes (CAREFUL - deletes data)
docker-compose down -v

# Restart services
docker-compose restart

# Execute command inside container
docker-compose exec newznab [command]

# View resource usage
docker stats newznab-tmux
```

## Performance Optimization

### For Large Usenet Indexes

**Recommended settings:**

```env
PHP_MEMORY_LIMIT=1024M         # Increase for large processing
PHP_MAX_EXECUTION_TIME=600     # Longer timeout for indexing jobs
MEILISEARCH_KEY=your-secure-key
```

**Increase queue workers:** Edit `supervisord.conf`
```ini
[program:newznab-worker-default]
numprocs=4          # Increase from 2 to 4+ on high-core systems

[program:newznab-worker-releases]
numprocs=4          # Match worker-default
```

**Database optimization:**
```bash
# Inside container, run:
docker-compose exec newznab mysql -u newznab -p newznab

# Add key index for performance:
ALTER TABLE releases ADD INDEX idx_name_date (name, created_at);
ALTER TABLE releases ADD INDEX idx_nfo (nfo);
```

**Redis performance:** Already configured with persistence enabled

**Hardware recommendations:**
- **CPU**: 8+ cores for heavy indexing
- **RAM**: 32GB+ for large indexes
- **Storage**: NVMe SSD for MariaDB and Meilisearch
- **Network**: Dedicated to Usenet provider connection

## Troubleshooting

### Container Won't Start

```bash
# Check full logs
docker-compose logs

# Common issues:
# 1. Port already in use
netstat -tulpn | grep 8080
# Solution: Use different port in docker-compose or kill process on 8080

# 2. Insufficient disk space
df -h /mnt/user/appdata/

# 3. Permissions issue on appdata folder
ls -la /mnt/user/appdata/newznab/
```

### Services Not Starting

```bash
# Check all services inside container
docker-compose exec newznab supervisorctl status

# Restart failed services
docker-compose exec newznab supervisorctl restart all

# View specific service logs
docker-compose exec newznab tail -f /var/log/supervisor/mariadb.log
docker-compose exec newznab tail -f /var/log/supervisor/redis.log
docker-compose exec newznab tail -f /var/log/supervisor/nginx.log
```

### Database Connection Issues

```bash
# Test database from inside container
docker-compose exec newznab mysql -u newznab -p newznab -e "SELECT 1;"

# Test from PHP
docker-compose exec newznab php artisan tinker
# In tinker: DB::connection()->getPDO();
```

### Web Interface Not Accessible

```bash
# Check if Nginx is running
docker-compose exec newznab supervisorctl status nginx

# Test port binding
docker ps | grep newznab

# Check if port is in use on host
lsof -i :8080

# Test directly inside container
docker-compose exec newznab curl http://localhost/
```

### Queue Jobs Not Processing

```bash
# Check Supervisor status
docker-compose exec newznab supervisorctl status

# View worker logs
docker-compose exec newznab tail -f /var/log/supervisor/worker-default.log

# Check Redis connection
docker-compose exec newznab redis-cli ping

# View failed jobs
docker-compose exec newznab php artisan queue:failed
```

### High Memory/CPU Usage

```bash
# Monitor resource usage
docker stats newznab-tmux

# Check process memory inside container
docker-compose exec newznab ps aux --sort=-%mem

# Reduce worker processes in supervisord.conf
# numprocs=2 → numprocs=1

# Adjust PHP memory limit
# PHP_MEMORY_LIMIT=512M → PHP_MEMORY_LIMIT=256M (if needed)
```

### Meilisearch Index Not Updating

```bash
# Check Meilisearch status
docker-compose exec newznab curl http://localhost:7700/health

# View Meilisearch logs
docker-compose exec newznab tail -f /var/log/supervisor/meilisearch.log

# Rebuild index
docker-compose exec newznab php artisan search:index-rebuild
```

## Updates and Maintenance

### Update Application

```bash
# Backup database first!
docker-compose exec newznab mysqldump -u newznab -p newznab > backup_$(date +%Y%m%d).sql

# Stop container
docker-compose down

# Rebuild with latest code
docker-compose up -d --build

# Run database migrations
docker-compose exec newznab php artisan migrate --force
```

### Backup Strategy

**Recommended: Daily automated backups**

```bash
# Manual backup
docker-compose exec newznab mysqldump -u newznab -p newznab > backup_$(date +%Y%m%d).sql

# Full volume backup (includes everything)
docker run --rm -v newznab-tmux_newznab-mysql:/data -v $(pwd):/backup \
  alpine tar czf /backup/newznab-mysql-backup.tar.gz -C /data .

# Copy to external storage
cp backup_*.sql /mnt/user/backups/
```

### Restore from Backup

```bash
# Restore database
docker-compose exec newznab mysql -u newznab -p newznab < backup_20250126.sql
```

## Security Recommendations

1. **Change all default passwords** in `.env`
2. **Use SSL/TLS** (nginx reverse proxy outside)
3. **Restrict access** to admin panel
4. **Keep dependencies updated** regularly
5. **Monitor logs** for suspicious activity
6. **Use strong API keys** for external services
7. **Implement backup strategy** for database

## Resources

- **Project:** https://github.com/NNTmux/newznab-tmux
- **Documentation:** https://github.com/NNTmux/newznab-tmux/wiki
- **Issues:** https://github.com/NNTmux/newznab-tmux/issues
- **Docker Docs:** https://docs.docker.com
- **Unraid Docs:** https://docs.unraid.net

## Support

For issues related to:
- **Newznab-tmux:** Visit the project GitHub
- **Docker setup:** Check Docker Compose documentation
- **Unraid:** Visit Unraid community forums

## License

This Docker configuration is provided as-is. Newznab-tmux is licensed under its original project license.
