# Newznab-tmux Docker Files Guide

This directory contains everything needed to deploy Newznab-tmux on Unraid or any Docker-capable system.

## File Descriptions

### Core Docker Files

#### `Dockerfile`
- Multi-stage build for optimized final image size
- Installs PHP 8.4 with all required extensions (pdo_mysql, curl, gd, zip, intl, mbstring, xml, pcntl)
- Installs optional tools (unrar, 7zip, ffmpeg, mediainfo)
- Installs Composer and Node.js
- Runs `composer install` and `npm run build`
- Sets proper file permissions and creates non-root user

**Key features:**
- Alpine Linux base for small image size
- Multi-stage to reduce final layer size
- Security: runs as non-root laravel user

#### `docker-compose.yml`
- Orchestrates all services needed for Newznab-tmux
- Services included:
  - **app**: PHP-FPM application container
  - **nginx**: Reverse proxy web server
  - **db**: MariaDB database
  - **redis**: Cache and queue backend
  - **meilisearch**: Full-text search engine
  - **supervisor**: Background job processor

**Configuration:**
- Health checks for all services
- Volume persistence for data
- Environment variable injection
- Container restart policies
- Network isolation

### Configuration Files

#### `.env.example`
- Template for environment configuration
- Copy to `.env` and customize for your setup
- Contains database, Redis, Meilisearch settings
- Optional API keys for TMDB, OMDB, TVMaze, Trakt
- PHP resource limits and mail settings

#### `php.ini`
- PHP configuration for the application
- Memory limit: 512MB (adjustable)
- Execution timeout: 300 seconds
- Enables all required extensions
- Security settings (disabled functions)

#### `www.conf`
- PHP-FPM pool configuration
- Process manager set to dynamic
- Max processes: 50 (adjustable)
- Child process settings

#### `supervisord.conf`
- Configuration for Supervisor daemon
- Manages queue worker processes
- Runs Laravel scheduler
- Log files for debugging

#### `nginx.conf`
- Nginx web server configuration
- PHP-FPM upstream configuration
- Security headers (X-Frame-Options, CSP, etc)
- Gzip compression
- Client max body size: 100MB
- Static asset caching

### Deployment Files

#### `unraid-template.xml`
- Unraid container template
- Allows one-click deployment from Unraid WebUI
- Pre-configured ports, volumes, and environment variables
- Includes links to documentation and GitHub

**How to use:**
1. Place in Unraid templates directory OR
2. Use "Custom" option in Docker tab and paste content

#### `unraid-deploy.sh`
- Bash script for automated Unraid deployment
- Creates directory structure
- Generates secure random passwords
- Sets proper permissions
- SSH into Unraid and run: `bash unraid-deploy.sh`

### Documentation

#### `README.md`
- Comprehensive deployment and configuration guide
- Installation methods (template and manual)
- Directory structure explanation
- Configuration reference table
- Database setup and management
- Performance tuning recommendations
- Troubleshooting section
- Backup and update procedures
- Security recommendations

#### `QUICKSTART.md`
- Quick reference for getting started
- Unraid automated deployment
- Docker Compose local deployment
- First-time access instructions
- Common commands
- Basic troubleshooting

#### `FILES_GUIDE.md` (This file)
- Description of all files in the repository
- File purposes and relationships
- How to use each component

### Build Helpers

#### `.dockerignore`
- Tells Docker which files to exclude from build context
- Reduces build time and image size
- Excludes git files, node_modules, vendor, logs, etc.

## File Organization

```
newznab-tmux-docker/
├── Dockerfile                 # Application container build
├── docker-compose.yml         # Service orchestration
├── .env.example              # Environment template
├── .dockerignore              # Build exclusions
│
├── php.ini                    # PHP configuration
├── www.conf                   # PHP-FPM configuration
├── nginx.conf                 # Nginx web server config
├── supervisord.conf           # Background job management
│
├── unraid-template.xml        # Unraid deployment template
├── unraid-deploy.sh          # Unraid automation script
│
├── README.md                  # Full documentation
├── QUICKSTART.md             # Quick start guide
└── FILES_GUIDE.md            # This file
```

## How Files Work Together

1. **Build Process:**
   - `Dockerfile` is used by `docker-compose up --build`
   - `.dockerignore` excludes unnecessary files
   - Result: Application container image

2. **Service Orchestration:**
   - `docker-compose.yml` defines all services
   - Loads `.env` for environment variables
   - Mounts configuration files (nginx.conf, php.ini, etc)
   - Starts and manages all containers

3. **Configuration:**
   - `.env.example` → Copy to `.env` or `config/.env`
   - `php.ini` → Loaded into PHP container
   - `www.conf` → PHP-FPM configuration
   - `nginx.conf` → Nginx configuration
   - `supervisord.conf` → Background job configuration

4. **Unraid Deployment:**
   - `unraid-template.xml` → Import into Unraid WebUI
   - `unraid-deploy.sh` → Automated setup on Unraid
   - Both reference the Docker files above

## Customization

### Modify Resource Limits
Edit `docker-compose.yml` and `php.ini`:
- `PHP_MEMORY_LIMIT`: Change in `docker-compose.yml` env vars
- Worker processes: Modify `www.conf` pm settings
- Supervisor workers: Edit `supervisord.conf`

### Change Database
Edit `Dockerfile` to use PostgreSQL instead of MariaDB:
- Update PHP extensions
- Modify `docker-compose.yml` db service
- Update `.env` connection settings

### Add SSL/TLS
Modify `nginx.conf`:
- Add certificate paths
- Configure SSL protocols
- Redirect HTTP to HTTPS

### Customize Search Engine
Edit `docker-compose.yml` and `.env`:
- Replace Meilisearch with Elasticsearch
- Update image names and ports
- Adjust connection settings

## File Sizes (Approximate)

| File | Size | Purpose |
|------|------|---------|
| Dockerfile | 2KB | Application build |
| docker-compose.yml | 3KB | Service orchestration |
| nginx.conf | 4KB | Web server config |
| supervisord.conf | 2KB | Job management |
| php.ini | 1KB | PHP settings |
| Other configs | 1KB | Various settings |

## Dependencies

### Required
- Docker (20.10+)
- Docker Compose (1.29+)
- Git (for cloning)

### Optional
- OpenSSL (for password generation)
- Text editor (for .env customization)

## Support

- **Issues with files**: Check README.md and QUICKSTART.md
- **Docker questions**: See docker-compose.yml comments
- **Newznab-tmux help**: Visit GitHub repository
- **Unraid help**: Check Unraid documentation

## Version History

- **v1.0** - Initial release
  - PHP 8.4 with Laravel support
  - Meilisearch integration
  - Full Unraid template support
  - Supervisor for background jobs
