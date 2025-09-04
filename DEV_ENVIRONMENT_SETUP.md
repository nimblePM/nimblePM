# NimbleEngineer Development Environment Setup

## 🎯 Overview
This guide helps you replicate the NimbleEngineer OpenProject stack on a new development VM at `dev.nimble.engineer`. This setup creates an isolated development branch while maintaining the ability to sync with production.

## 📋 Prerequisites

### System Requirements
- **OS**: Ubuntu 22.04 LTS (recommended, matches production)
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 20GB minimum, 50GB recommended
- **Network**: Static IP or DHCP reservation recommended

### Required Software
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install legacy docker-compose (if needed)
sudo apt install -y docker-compose

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect

# Install Git
sudo apt install -y git curl wget

# Install Cloudflared (for tunnels)
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
rm cloudflared.deb
```

## 🚀 Repository Setup

### 1. Clone Your Fork
```bash
# Clone your NimbleEngineer fork
git clone https://github.com/nimblePM/nimblePM.git nimbleengineer-dev
cd nimbleengineer-dev

# Add upstream for OpenProject updates
git remote add upstream https://github.com/opf/openproject.git

# Create and switch to development branch
git checkout -b nimble-dev
git push origin -u nimble-dev
```

### 2. Create Development Environment File
```bash
# Copy production config as template
cp env.production env.development

# Edit for development settings
nano env.development
```

**Edit `env.development` with these changes:**
```bash
# nimblePM Development Configuration
# For dev VM at dev.nimble.engineer

# OpenProject version
TAG=16-slim

# External PostgreSQL 17 Database Configuration  
DB_HOST=192.168.3.78  # Keep same DB or use local
DB_PORT=5432
DB_USER=openproject_dev  # Different user for dev
DB_PASSWORD=openproject_dev
DB_NAME=openproject_dev  # Separate dev database

# Construct DATABASE_URL from components
DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}

# Secret key base - GENERATE NEW FOR DEV
SECRET_KEY_BASE=YOUR_NEW_DEV_SECRET_KEY_HERE

# Host configuration for dev.nimble.engineer
OPENPROJECT_HOST__NAME=dev.nimble.engineer
OPENPROJECT_PROTOCOL=https
OPENPROJECT_HTTPS=true

# Port binding
PORT=3000

# Admin password - Different from production
ADMIN_PASSWORD=devadmin123

# Worker configuration (lighter for dev)
WEB_WORKERS=1
WEB_MIN_THREADS=1
WEB_MAX_THREADS=2
WORKER_MAX_THREADS=2

# Edition
OPENPROJECT_EDITION=standard

# Data volumes path
OPDATA=/var/openproject/assets

# Development CSP (more permissive)
OPENPROJECT_SECURITY_HEADERS_CONTENT_SECURITY_POLICY="default-src 'self' https: 'unsafe-inline' 'unsafe-eval'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; connect-src 'self' https: wss: ws:; img-src 'self' https: data:; style-src 'self' 'unsafe-inline' https:; font-src 'self' https: data:;"
```

### 3. Generate New Secret Key
```bash
# Generate a new secret key for development
openssl rand -hex 64
# Copy this into your env.development file
```

## 🗄️ Database Setup

### Option 1: Shared Database (Separate Schema)
```bash
# Connect to your PostgreSQL server (192.168.3.78)
psql -h 192.168.3.78 -U postgres

-- Create development database and user
CREATE DATABASE openproject_dev;
CREATE USER openproject_dev WITH PASSWORD 'openproject_dev';
GRANT ALL PRIVILEGES ON DATABASE openproject_dev TO openproject_dev;
\q
```

### Option 2: Local PostgreSQL (Isolated)
```bash
# Install PostgreSQL locally
sudo apt install -y postgresql postgresql-contrib

# Create local database
sudo -u postgres createdb openproject_dev
sudo -u postgres createuser openproject_dev
sudo -u postgres psql -c "ALTER USER openproject_dev PASSWORD 'openproject_dev';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE openproject_dev TO openproject_dev;"

# Update env.development to use localhost
DB_HOST=localhost
```

## 🐳 Development Modifications

### 1. Remove SAML (Development Simplification)
```bash
# Edit docker-compose.yml or create docker-compose.dev.yml
# Remove SAML environment variables and volumes

# In your development environment, comment out or remove:
# - SAML-related environment variables
# - SAML certificate mounts
# - Any SAML-specific configurations
```

### 2. Create Development Docker Override
```bash
# Create docker-compose.override.yml for dev-specific settings
cat > docker-compose.override.yml << 'EOF'
version: '3.8'

services:
  backend:
    environment:
      # Development-specific overrides
      RAILS_ENV: development
      OPENPROJECT_LOG__LEVEL: debug
      OPENPROJECT_RAILS__RELATIVE__URL__ROOT: ""
    ports:
      - "3000:3000"
    # Mount source for development
    volumes:
      - ./app:/app/app:ro
      - ./config:/app/config:ro
      - ./lib:/app/lib:ro
      # Add any other source mounts you want to edit live

  worker:
    environment:
      RAILS_ENV: development
      OPENPROJECT_LOG__LEVEL: debug
EOF
```

## 🌐 Cloudflare Tunnel Setup

### 1. Authenticate Cloudflared
```bash
# Login to Cloudflare
cloudflared tunnel login

# Create tunnel for dev environment
cloudflared tunnel create nimble-dev

# Note the tunnel UUID for configuration
```

### 2. Configure Tunnel
```bash
# Create config directory
mkdir -p ~/.cloudflared

# Create tunnel configuration
cat > ~/.cloudflared/config.yml << 'EOF'
tunnel: YOUR_TUNNEL_UUID_HERE
credentials-file: /home/$USER/.cloudflared/YOUR_TUNNEL_UUID_HERE.json

ingress:
  # OpenProject dev instance
  - hostname: dev.nimble.engineer
    service: http://localhost:3000
  
  # SSH access
  - hostname: ssh-dev.nimble.engineer
    service: ssh://localhost:22
  
  # Future: Flowise dev instance
  - hostname: ask-dev.nimble.engineer
    service: http://localhost:3001
  
  # Catch-all
  - service: http_status:404
EOF

# Start tunnel service
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

### 3. DNS Configuration
In Cloudflare DNS, add CNAME records:
- `dev.nimble.engineer` → `YOUR_TUNNEL_UUID.cfargotunnel.com`
- `ssh-dev.nimble.engineer` → `YOUR_TUNNEL_UUID.cfargotunnel.com`
- `ask-dev.nimble.engineer` → `YOUR_TUNNEL_UUID.cfargotunnel.com`

## 🚀 Launch Development Environment

### 1. Start Services
```bash
cd nimbleengineer-dev

# Build and start with development config
sudo docker compose --env-file env.development up -d --build

# Check logs
sudo docker compose --env-file env.development logs -f --tail=100
```

### 2. Initial Setup
```bash
# Wait for services to start, then access:
# https://dev.nimble.engineer

# Login with:
# Username: admin
# Password: devadmin123 (or whatever you set in env.development)
```

## 🔧 Development Workflow

### Daily Development
```bash
# Pull latest from your production branch
git fetch origin
git merge origin/nimble-production  # Merge production changes

# Make development changes
# ... edit files ...

# Commit to dev branch
git add .
git commit -m "dev: your development changes"
git push origin nimble-dev
```

### Sync with OpenProject Upstream (Optional)
```bash
# Fetch latest OpenProject updates
git fetch upstream

# Review changes (optional)
git log --oneline nimble-dev..upstream/dev | head -20

# Merge specific features (be selective!)
git cherry-pick COMMIT_HASH  # For specific commits
# OR
git merge upstream/dev  # For full merge (be careful!)
```

### Deploy Changes to Production
```bash
# When ready, merge dev changes to production
git checkout nimble-production
git merge nimble-dev
git push origin nimble-production

# Then deploy to production server
```

## 🛠️ Customizations for Development

### Remove SAML Authentication
1. Edit `config/initializers/` files to disable SAML
2. Remove SAML gems from Gemfile if needed
3. Simplify authentication to basic login

### Enable Development Features
```bash
# Add to env.development:
RAILS_ENV=development
OPENPROJECT_LOG__LEVEL=debug
OPENPROJECT_RAILS__CACHE=false  # Disable caching for dev
```

### MCP Server Development
```bash
# If developing MCP server, create dev version
cp openproject_mcp.py openproject_mcp_dev.py

# Edit connection settings for dev database
# Run in development mode with different port
```

## 🔍 Troubleshooting

### Common Issues
1. **Database Connection**: Ensure PostgreSQL allows connections from your dev VM
2. **Docker Permissions**: Make sure user is in docker group
3. **Port Conflicts**: Check nothing else is using port 3000
4. **SSL Issues**: Cloudflare handles SSL, ensure HTTPS is enabled in config

### Useful Commands
```bash
# Check service status
sudo docker compose --env-file env.development ps

# View logs
sudo docker compose --env-file env.development logs backend

# Restart services
sudo docker compose --env-file env.development restart

# Clean rebuild
sudo docker compose --env-file env.development down
sudo docker compose --env-file env.development up -d --build
```

## 📁 File Structure
```
nimbleengineer-dev/
├── AI_CHAT_INSTRUCTIONS.md
├── docker-compose.yml
├── docker-compose.override.yml  # Dev overrides
├── env.development              # Dev environment config
├── env.production              # Production reference
├── mcp-server/                 # MCP server code
├── openproject_mcp_dev.py      # Dev MCP server
└── README.md
```

## 🎯 Next Steps

1. **Set up the VM** with Ubuntu 22.04
2. **Install prerequisites** (Docker, Git, Cloudflared)
3. **Clone and configure** the repository
4. **Set up database** (shared or local)
5. **Configure Cloudflare tunnel**
6. **Launch and test** the development environment
7. **Start developing** with your isolated nimble-dev branch

This setup gives you a complete development environment that's isolated from production but can sync changes bidirectionally when ready.
