#!/bin/bash

# Newznab-tmux Unraid Deployment Script
# Run this script to quickly deploy newznab-tmux on Unraid

set -e

APPDATA_PATH="/mnt/user/appdata/newznab"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Newznab-tmux Unraid Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if running on Unraid
if [ ! -d "/mnt/user" ]; then
    echo -e "${RED}Error: Not running on Unraid (no /mnt/user directory found)${NC}"
    exit 1
fi

# Create appdata directory
echo -e "${YELLOW}Creating appdata directory...${NC}"
mkdir -p "$APPDATA_PATH"/{config,nzbs,storage}
chmod 755 "$APPDATA_PATH"

# Copy docker-compose.yml
echo -e "${YELLOW}Copying Docker Compose configuration...${NC}"
cp "$SCRIPT_DIR/docker-compose.yml" "$APPDATA_PATH/"
cp "$SCRIPT_DIR/Dockerfile" "$APPDATA_PATH/"
cp "$SCRIPT_DIR/nginx.conf" "$APPDATA_PATH/"
cp "$SCRIPT_DIR/php.ini" "$APPDATA_PATH/"
cp "$SCRIPT_DIR/www.conf" "$APPDATA_PATH/"
cp "$SCRIPT_DIR/supervisord.conf" "$APPDATA_PATH/config/"

# Copy and setup .env file
echo -e "${YELLOW}Setting up environment configuration...${NC}"
if [ ! -f "$APPDATA_PATH/config/.env" ]; then
    cp "$SCRIPT_DIR/.env.example" "$APPDATA_PATH/config/.env"

    # Generate secure random passwords
    DB_PASS=$(openssl rand -base64 16 | tr -d '\n')
    DB_ROOT_PASS=$(openssl rand -base64 16 | tr -d '\n')
    APP_KEY=$(openssl rand -base64 32 | tr -d '\n')
    MEILI_KEY=$(openssl rand -base64 32 | tr -d '\n')

    # Update .env with generated passwords (use | as sed delimiter to avoid issues with / in base64)
    sed -i "s|DB_PASSWORD=newznabpassword|DB_PASSWORD=$DB_PASS|g" "$APPDATA_PATH/config/.env"
    sed -i "s|DB_ROOT_PASSWORD=rootpassword|DB_ROOT_PASSWORD=$DB_ROOT_PASS|g" "$APPDATA_PATH/config/.env"
    sed -i "s|APP_KEY=|APP_KEY=$APP_KEY|g" "$APPDATA_PATH/config/.env"
    sed -i "s|MEILISEARCH_KEY=changeme|MEILISEARCH_KEY=$MEILI_KEY|g" "$APPDATA_PATH/config/.env"

    echo -e "${GREEN}✓ .env file created with secure passwords${NC}"
else
    echo -e "${YELLOW}✓ .env file already exists (skipping)${NC}"
fi

# Copy .env to docker context
ln -sf "$APPDATA_PATH/config/.env" "$APPDATA_PATH/.env" 2>/dev/null || true

# Set permissions
echo -e "${YELLOW}Setting directory permissions...${NC}"
chown -R nobody:users "$APPDATA_PATH"
chmod 755 "$APPDATA_PATH"/{config,nzbs,storage}

# Display next steps
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment files ready!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Review configuration:"
echo -e "   ${YELLOW}nano $APPDATA_PATH/config/.env${NC}"
echo ""
echo "2. Start containers:"
echo -e "   ${YELLOW}cd $APPDATA_PATH${NC}"
echo -e "   ${YELLOW}docker-compose up -d${NC}"
echo ""
echo "3. Initialize database:"
echo -e "   ${YELLOW}docker-compose exec newznab php artisan migrate --force${NC}"
echo -e "   ${YELLOW}docker-compose exec newznab php artisan db:seed${NC}"
echo ""
echo "4. Access web interface:"
echo -e "   ${YELLOW}http://[unraid-ip]:8080${NC}"
echo ""
echo "5. Monitor logs:"
echo -e "   ${YELLOW}docker-compose logs -f${NC}"
echo ""
echo -e "${YELLOW}For more information, see README.md${NC}"
echo ""
