# Newznab-tmux Docker Setup for Unraid

This is a complete Docker setup for deploying [Newznab-tmux](https://github.com/NNTmux/newznab-tmux) on Unraid. The setup includes all necessary services: PHP-FPM, Nginx, MariaDB, Redis, Meilisearch, and Supervisor for background jobs.

## Features

- **Multi-stage Docker build** for optimized image size
- **Full Laravel stack** with all required PHP extensions
- **Database support** for MariaDB/MySQL
- **Caching & queuing** with Redis
- **Full-text search** with Meilisearch
- **Background job processing** with Supervisor
- **Nginx reverse proxy** with security headers
- **Unraid template** for easy deployment
- **Docker Compose** for local development/testing

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
   - Adjust port bindings (default 8080 for web UI)
   - Create appdata directory: `/mnt/user/appdata/newznab`
   - Allocate storage for NZB files: `/mnt/user/appdata/newznab/nzbs`

3. **Set Environment Variables:**
   - Copy values from `.env.example` to `.env`
   - Change all `changeme` passwords to secure values
   - Set `APP_URL` to your Unraid server IP/hostname

4. **Start Container:**
   - Click **Add** or **Start**
   - Monitor logs for initialization

### Method 2: Manual Docker Compose (Recommended for Testing)

1. **Clone or download this directory:**
   ```bash
   cd /mnt/user/appdata
   git clone <this-repo> newznab-tmux
   cd newznab-tmux
   ```

2. **Setup Environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   nano .env
   ```

3. **Create Config Directory:**
   ```bash
   mkdir -p config
   cp .env config/.env
   ```

4. **Build and Start Services:**
   ```bash
   docker-compose up -d
   ```

5. **Initialize Database:**
   ```bash
   docker-compose exec app php artisan migrate --force
   docker-compose exec app php artisan db:seed
   ```

6. **Access Web Interface:**
   - Navigate to `http://localhost:8080` (or your Unraid IP:8080)

## Directory Structure

```
/mnt/user/appdata/newznab/
├── storage/              # Application storage (logs, uploads, etc)
├── nzbs/                # NZB files directory
├── config/              # Configuration files
│   └── .env            # Environment configuration
├── docker-compose.yml   # Docker Compose file
├── Dockerfile          # Container build file
└── nginx.conf          # Nginx web server config
```

## Configuration

### Important Settings in `.env`

| Variable | Description | Example |
|----------|-------------|---------|
| `APP_URL` | Your server URL | `http://192.168.1.100:8080` |
| `DB_PASSWORD` | Database password | Must change from default |
| `MEILISEARCH_KEY` | Search engine key | Must change from default |
| `TMDB_API_KEY` | TMDB API key (optional) | Get from themoviedb.org |
| `OMDB_API_KEY` | OMDB API key (optional) | Get from omdbapi.com |

### Database Configuration

The setup uses MariaDB 10.6+. Default credentials:
- **Database:** newznab
- **User:** newznab
- **Password:** changeme (in `.env`)

Change these in `.env` before first run.

### Search Engine

Uses Meilisearch by default for full-text search. Alternative is Elasticsearch if needed.

## Volumes and Storage

### Persistent Volumes

- `app-storage`: Laravel storage directory (logs, session data)
- `app-cache`: Laravel bootstrap cache
- `db-data`: MariaDB data
- `redis-data`: Redis data
- `meilisearch-data`: Search index data
- `nzb-store`: NZB files storage

### Host Paths (Unraid)

All data is stored in `/mnt/user/appdata/newznab/`:
- Store critical data on pool or SSD
- Ensure sufficient free space for growing index

## Initial Setup

### First Run Checklist

1. **Change all default passwords** in `.env`
2. **Generate APP_KEY:**
   ```bash
   docker-compose exec app php artisan key:generate
   ```
3. **Run migrations:**
   ```bash
   docker-compose exec app php artisan migrate --force
   ```
4. **Create admin user:**
   ```bash
   docker-compose exec app php artisan tinker
   # In tinker:
   # User::create(['username' => 'admin', 'email' => 'admin@example.com', 'password' => bcrypt('password'), 'role_id' => 1]);
   # exit
   ```
5. **Set proper permissions:**
   ```bash
   docker-compose exec app chmod -R 775 storage bootstrap/cache
   ```

### Accessing Web Interface

- **URL:** `http://[unraid-ip]:8080`
- **Default admin username:** admin
- **Default admin password:** admin (CHANGE THIS IMMEDIATELY)

## Management

### Viewing Logs

```bash
# All logs
docker-compose logs -f

# Specific service
docker-compose logs -f app
docker-compose logs -f nginx
docker-compose logs -f db

# Supervisor workers
docker-compose logs -f supervisor
```

### Database Maintenance

```bash
# Connect to MySQL
docker-compose exec db mysql -u newznab -p newznab

# Backup database
docker-compose exec db mysqldump -u newznab -p newznab > backup.sql

# Restore database
docker-compose exec db mysql -u newznab -p newznab < backup.sql
```

### Monitor Queue Jobs

```bash
docker-compose exec app php artisan queue:failed
docker-compose exec app php artisan queue:retry all
```

## Performance Tuning

### For Large Usenet Indexes

1. **Increase PHP memory:**
   ```env
   PHP_MEMORY_LIMIT=1024M
   ```

2. **Increase worker processes:**
   Edit `supervisord.conf` and increase `numprocs`

3. **Database optimization:**
   - Add indexes to frequently queried tables
   - Monitor slow query log
   - Consider dedicated database server

4. **Redis performance:**
   - Use RDB persistence with `--appendonly yes`
   - Monitor memory usage
   - Implement key eviction policy

## Troubleshooting

### Container Won't Start

1. Check logs: `docker-compose logs app`
2. Verify environment variables are set
3. Ensure database is healthy: `docker-compose ps`
4. Check disk space: `df -h`

### Database Connection Issues

```bash
# Test database connection
docker-compose exec app php artisan tinker
# In tinker: DB::connection()->getPDO();
```

### Queue Jobs Not Processing

1. Verify Supervisor is running: `docker-compose logs supervisor`
2. Check Redis connection: `docker-compose exec redis redis-cli ping`
3. View failed jobs: `docker-compose exec app php artisan queue:failed`

### High Memory Usage

- Monitor with `docker stats`
- Reduce PHP-FPM `max_children`
- Reduce Supervisor worker count
- Check for memory leaks in queue jobs

## Updates

### Update Application

```bash
cd /mnt/user/appdata/newznab
git pull origin main
docker-compose down
docker-compose up -d --build
docker-compose exec app php artisan migrate
```

### Backup Before Updates

```bash
docker-compose exec db mysqldump -u newznab -p newznab > backup_$(date +%Y%m%d).sql
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
