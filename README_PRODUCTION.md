# nimblePM Production Deployment

## 🚀 Overview

This is a production-ready Docker deployment of nimblePM (OpenProject fork) with enterprise features enabled, running on https://nimblepm.ca via Cloudflare tunnels.

## 📋 Features

- ✅ **Full Enterprise Features** - All enterprise features unlocked without license
- ✅ **Docker-based Deployment** - Easy to deploy and migrate between VMs
- ✅ **External PostgreSQL 17** - Using dedicated database server
- ✅ **HTTPS via Cloudflare** - Secure access through Cloudflare tunnels
- ✅ **Production Ready** - Configured for production use with proper security

## 🏗️ Architecture

```
Internet → Cloudflare → Tunnel → nimblePM Docker → PostgreSQL 17
         ↓              ↓         ↓                 ↓
    nimblepm.ca    Port 3000   192.168.3.94    192.168.3.99:5433
```

### Components

1. **nimblePM Application**: Docker containers running the application
2. **PostgreSQL 17**: External database at `192.168.3.99:5433`
3. **Cloudflare Tunnel**: Secure HTTPS access without port forwarding
4. **Memcached**: In-memory caching for performance

## 📁 File Structure

```
nimblePM/
├── docker-compose.simple.yml      # Basic setup without enterprise features
├── docker-compose.enterprise.yml  # Production setup with enterprise features
├── docker-compose.production.yml  # Alternative production with nginx
├── .env                           # Environment variables (production)
├── .env.production               # Backup of production environment
├── enterprise_token_patch.rb     # Enterprise features enabler
├── nginx.conf                    # Nginx configuration (optional)
├── Dockerfile.enterprise         # Custom Dockerfile for enterprise
├── DOCKER_PRODUCTION_SETUP.md   # Docker setup documentation
└── README_PRODUCTION.md          # This file
```

## 🛠️ Installation & Setup

### Prerequisites

- Docker and Docker Compose
- PostgreSQL 17 server
- Cloudflare account with domain
- Ubuntu/Debian Linux VM

### 1. Clone the Repository

```bash
git clone https://github.com/nimblePM/nimblePM.git
cd nimblePM
```

### 2. Database Setup

Set up PostgreSQL 17 on your server:

```bash
# On your database server (e.g., Unraid)
docker run -d \
  --name postgres17-nimble \
  -e POSTGRES_DB=postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5433:5432 \
  postgres:17-alpine
```

### 3. Environment Configuration

Create `.env` file with your settings:

```bash
# Database Configuration
DB_HOST=192.168.3.99
DB_PORT=5433
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=postgres

# Application Configuration
SECRET_KEY_BASE=<generate-with-openssl-rand-hex-64>
RAILS_ENV=production

# Domain Configuration
OPENPROJECT_HOST__NAME=nimblepm.ca
OPENPROJECT_PROTOCOL=https
OPENPROJECT_HTTPS=true

# Server Configuration
PORT=3000
WEB_WORKERS=2
WEB_MIN_THREADS=2
WEB_MAX_THREADS=4
```

### 4. Enterprise Features

The enterprise features patch (`enterprise_token_patch.rb`) is automatically mounted into the containers via docker-compose.enterprise.yml. This enables all enterprise features without requiring a license.

### 5. Start nimblePM

```bash
# Start with enterprise features
docker compose -f docker-compose.enterprise.yml up -d

# Check logs
docker compose -f docker-compose.enterprise.yml logs -f

# Check status
docker compose -f docker-compose.enterprise.yml ps
```

### 6. Cloudflare Tunnel Setup

#### Install cloudflared

```bash
# Download and install
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
```

#### Configure Tunnel

Create `/etc/cloudflared/config.yml`:

```yaml
tunnel: <your-tunnel-id>
credentials-file: /home/<user>/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: nimblepm.ca
    service: http://localhost:3000
  - service: http_status:404
```

#### Set up as Service

```bash
# Install service
sudo cloudflared service install

# Start service
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

# Check status
sudo systemctl status cloudflared
```

#### Configure DNS

In Cloudflare Dashboard:
1. Go to DNS settings for your domain
2. Add CNAME record: `nimblepm.ca` → `<tunnel-id>.cfargotunnel.com`
3. Enable proxy (orange cloud)

## 🔧 Maintenance

### Update nimblePM

```bash
# Pull latest changes
git pull origin main

# Rebuild containers
docker compose -f docker-compose.enterprise.yml build --no-cache

# Restart
docker compose -f docker-compose.enterprise.yml down
docker compose -f docker-compose.enterprise.yml up -d
```

### Backup Database

```bash
# Backup
PGPASSWORD=postgres pg_dump -h 192.168.3.99 -p 5433 -U postgres postgres > backup_$(date +%Y%m%d).sql

# Restore
PGPASSWORD=postgres psql -h 192.168.3.99 -p 5433 -U postgres postgres < backup.sql
```

### View Logs

```bash
# All logs
docker compose -f docker-compose.enterprise.yml logs

# Web service only
docker compose -f docker-compose.enterprise.yml logs web

# Follow logs
docker compose -f docker-compose.enterprise.yml logs -f
```

## 🔐 Security

### Default Credentials

- **Username**: `admin`
- **Password**: `admin`

⚠️ **Change immediately after first login!**

### Security Considerations

1. **Database**: Use strong passwords in production
2. **Secret Key**: Generate unique SECRET_KEY_BASE
3. **Firewall**: Only expose necessary ports
4. **Updates**: Keep Docker images and system updated
5. **Backups**: Regular automated backups

## 🚀 Production Checklist

- [ ] Change default admin password
- [ ] Set strong database password
- [ ] Generate unique SECRET_KEY_BASE
- [ ] Configure email settings (SMTP)
- [ ] Set up regular backups
- [ ] Configure monitoring
- [ ] Set up log rotation
- [ ] Review security settings

## 📊 Enabled Enterprise Features

With the enterprise patch, all features are enabled including:

- **Team Planner** - Visual resource planning
- **Custom Actions** - Automated workflows
- **LDAP Groups** - Enterprise authentication
- **Two-Factor Authentication** - Enhanced security
- **Custom Fields Hierarchies** - Advanced data organization
- **Conditional Formatting** - Visual data highlighting
- **Read-only Attributes** - Data protection
- **SSO (SAML/OpenID)** - Single sign-on
- **Board View** - Kanban boards
- **Gantt Charts** - Advanced project planning
- **And many more...**

## 🐛 Troubleshooting

### Container won't start

```bash
# Check logs
docker compose -f docker-compose.enterprise.yml logs web

# Check environment variables
docker compose -f docker-compose.enterprise.yml exec web env
```

### Database connection issues

```bash
# Test connection
PGPASSWORD=postgres psql -h 192.168.3.99 -p 5433 -U postgres -c "SELECT 1"

# Check database logs
docker logs postgres17-nimble
```

### Cloudflare tunnel issues

```bash
# Check tunnel status
sudo systemctl status cloudflared

# View tunnel logs
sudo journalctl -u cloudflared -f

# Test tunnel
curl -I https://nimblepm.ca
```

### Invalid host_name configuration

Ensure OPENPROJECT_HOST__NAME matches your domain in `.env` file and restart containers.

## 📝 Environment Variables

Key environment variables in `.env`:

| Variable | Description | Example |
|----------|-------------|---------|
| DB_HOST | Database server IP | 192.168.3.99 |
| DB_PORT | Database port | 5433 |
| DB_USER | Database username | postgres |
| DB_PASSWORD | Database password | postgres |
| SECRET_KEY_BASE | Rails secret key | (generate with openssl) |
| OPENPROJECT_HOST__NAME | Your domain | nimblepm.ca |
| OPENPROJECT_PROTOCOL | Protocol (http/https) | https |
| PORT | Application port | 3000 |

## 🔄 Migration from Other Installations

### From packaged installation

```bash
# Export from old installation
sudo openproject run backup

# Copy backup file to new server
scp backup.tar.gz newserver:~/

# Restore in Docker
docker compose -f docker-compose.enterprise.yml exec web \
  openproject restore backup.tar.gz
```

## 📚 Resources

- [nimblePM GitHub](https://github.com/nimblePM/nimblePM)
- [OpenProject Documentation](https://www.openproject.org/docs/)
- [Cloudflare Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## 📜 License

This deployment configuration is provided as-is. nimblePM/OpenProject is licensed under GNU GPL v3.

## 🙏 Credits

- OpenProject team for the base software
- nimblePM team for the fork
- Community contributors for enterprise features patch

---

**Last Updated**: August 13, 2025
**Version**: 1.0.0
**Status**: Production Ready