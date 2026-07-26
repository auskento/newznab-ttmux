# Quick Start Guide

## For Unraid Users

### Option 1: Automatic Deployment (Recommended)

1. **SSH into your Unraid server:**
   ```bash
   ssh root@[unraid-ip]
   ```

2. **Run the deployment script:**
   ```bash
   cd /tmp
   git clone https://github.com/NNTmux/newznab-tmux-docker.git
   cd newznab-tmux-docker
   chmod +x unraid-deploy.sh
   ./unraid-deploy.sh
   ```

3. **Start the containers:**
   ```bash
   cd /mnt/user/appdata/newznab
   docker-compose up -d
   ```

### Option 2: Manual Setup in Unraid WebUI

1. **Docker Tab:**
   - Go to your Unraid Dashboard → Docker tab
   - Click "Add Container"
   - Use this repository as template source

2. **Configure:**
   - Port: 8080 → 80
   - Appdata: `/mnt/user/appdata/newznab`
   - NZB Storage: `/mnt/user/appdata/newznab/nzbs`

3. **Start and initialize:**
   ```bash
   # In terminal
   docker-compose exec app php artisan migrate --force
   ```

## For Docker Compose Users (Testing)

### Prerequisites
- Docker & Docker Compose installed
- Clone this repository

### Deploy Locally

```bash
# Clone repository
git clone https://github.com/NNTmux/newznab-tmux-docker.git
cd newznab-tmux-docker

# Setup environment
cp .env.example config/.env

# Start services
docker-compose up -d

# Initialize database
docker-compose exec app php artisan migrate --force
docker-compose exec app php artisan db:seed

# Access at http://localhost:8080
```

## First Time Access

1. **Web Interface:**
   - URL: `http://[server-ip]:8080`
   - Default username: `admin`
   - Default password: `admin`

2. **IMPORTANT: Change Default Password Immediately**

3. **Configure API Keys:**
   - TMDB, OMDB, TVMaze, Trakt (optional but recommended)
   - Add in Settings → External APIs

## Common Commands

```bash
# View logs
docker-compose logs -f app

# Execute artisan command
docker-compose exec app php artisan [command]

# Connect to database
docker-compose exec db mysql -u newznab -p

# Stop containers
docker-compose down

# Restart service
docker-compose restart app
```

## Troubleshooting

### "Connection refused" to database
- Wait 30-60 seconds for MariaDB to fully start
- Check: `docker-compose ps` (all should show "Up")

### High CPU/Memory usage
- Reduce Supervisor worker count in `supervisord.conf`
- Adjust `PHP_MEMORY_LIMIT` down
- Monitor with: `docker stats`

### Queue jobs not processing
```bash
# Check supervisor status
docker-compose logs supervisor

# Restart supervisor
docker-compose restart supervisor
```

### Can't access web interface
- Check port is correct in `.env` (default 8080)
- Verify firewall allows traffic
- Check nginx logs: `docker-compose logs nginx`

## Next Steps

1. **Read README.md** for detailed configuration options
2. **Configure API keys** in web interface settings
3. **Add Usenet servers** in settings
4. **Monitor logs** while indexing starts
5. **Backup database** regularly

---

For more help, see the full README.md or visit the [Newznab-tmux GitHub](https://github.com/NNTmux/newznab-tmux).
