# nimblePM Docker Production Setup

## Overview

This is a Docker-based production deployment of nimblePM (OpenProject fork) configured to replicate the existing setup at nimble.engineer but with enhanced portability and easier VM migration.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Cloudflare    │    │    nginx proxy   │    │    nimblePM Web     │
│     Tunnel      │────│   (port 443)     │────│    (port 3000)     │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
                                                           │
                       ┌──────────────────┐    ┌─────────────────────┐
                       │   nimblePM       │    │   External DB       │
                       │   Background     │────│   192.168.3.18      │
                       │   Workers        │    │   PostgreSQL        │
                       └──────────────────┘    └─────────────────────┘
                                  │
                       ┌──────────────────┐
                       │    Memcached     │
                       │     Cache        │
                       └──────────────────┘
```

## Key Features

- **External Database**: Uses existing PostgreSQL at 192.168.3.18
- **Docker Containerization**: Easy deployment and migration between VMs
- **Production Ready**: Matches existing nimble.engineer configuration
- **Nginx Proxy**: SSL termination and reverse proxy (optional)
- **Background Jobs**: Separate worker container for async processing
- **Cloudflare Ready**: Configured for nimblepm.ca domain migration

## Files Structure

```
├── docker-compose.simple.yml     # Simple setup without nginx
├── docker-compose.production.yml # Full production with nginx
├── .env.production              # Production environment variables
├── nginx.conf                   # Nginx configuration
└── DOCKER_PRODUCTION_SETUP.md   # This documentation
```

## Quick Start

### 1. Environment Setup

The `.env.production` file contains all configuration:
- Database connection to 192.168.3.18
- SSL and domain settings for nimblepm.ca
- Security keys and passwords

### 2. Simple Deployment (Recommended for Testing)

```bash
# Start without nginx proxy
docker compose -f docker-compose.simple.yml --env-file .env.production up --build -d

# View logs
docker compose -f docker-compose.simple.yml logs -f

# Access at http://localhost:3000
```

### 3. Full Production Deployment

```bash
# Start with nginx proxy
docker compose -f docker-compose.production.yml --env-file .env.production up --build -d

# Access at http://localhost (port 80) or https://localhost (port 443)
```

## Configuration Details

### Database Configuration

- **Host**: 192.168.3.18
- **Database**: openproject
- **Username**: openproject
- **Password**: openproject (change in production)

### Security Configuration

- **Secret Key**: Pre-generated 128-character secure key
- **Admin Password**: Default is `admin` (change immediately after login)
- **SSL Settings**: Configured for Cloudflare Origin certificates

### Domain Migration Settings

Ready for migration to nimblepm.ca:
- Host name: nimblepm.ca
- Protocol: HTTPS
- SSL force redirect: Disabled (handled by Cloudflare)

## Migration from VM to VM

This setup is designed for easy migration:

1. **Copy files**: Just copy the entire directory
2. **Run Docker**: `docker compose up`  
3. **Database**: Already external, no migration needed
4. **Assets**: Stored in Docker volumes, persistent across restarts

## Cloudflare Tunnel Setup (Future)

When ready to expose externally:

```bash
# Install cloudflared
sudo apt install cloudflared

# Create tunnel
cloudflared tunnel create nimblepm-production

# Configure tunnel to point to http://127.0.0.1:3000
# (or https://127.0.0.1:443 if using nginx)

# Start tunnel
cloudflared tunnel run nimblepm-production
```

## Development vs Production

| Aspect | Development | This Production Setup |
|--------|-------------|----------------------|
| Database | Local container | External at 192.168.3.18 |
| Port | 4200 (frontend) + 3000 (backend) | 3000 (unified) |
| SSL | None | Nginx + Cloudflare certs |
| Workers | Combined | Separate container |
| Caching | File system | Memcached |
| Assets | Development server | Pre-compiled |

## Troubleshooting

### Build Issues
```bash
# Check build logs
docker compose logs web

# Rebuild without cache
docker compose build --no-cache
```

### Database Connection Issues
```bash
# Test database connectivity
pg_isready -h 192.168.3.18 -p 5432 -U openproject

# Check container logs
docker compose logs web worker
```

### Performance Issues
```bash
# Monitor resource usage
docker stats

# Check worker logs
docker compose logs worker
```

## Security Considerations

### Current Security
- Generated secure SECRET_KEY_BASE
- External database connection
- Memcached isolated to Docker network
- Nginx security headers (in full setup)

### Production Hardening TODO
- [ ] Change default admin password immediately
- [ ] Rotate database password
- [ ] Add SSL certificates to nginx.conf
- [ ] Configure proper backup strategy
- [ ] Set up monitoring and alerting
- [ ] Implement log rotation
- [ ] Configure fail2ban for login protection

## Performance Tuning

Current settings are optimized for single-server deployment:
- **Web Workers**: 2
- **Web Threads**: 2-4 per worker
- **Background Workers**: 5 threads max
- **Memcached**: Single instance

Scale up by adjusting `.env.production`:
```bash
WEB_WORKERS=4
WEB_MAX_THREADS=8
WORKER_MAX_THREADS=10
```

## Monitoring

### Health Checks
```bash
# Check all services
docker compose ps

# Check specific service health
curl http://localhost:3000/health_checks
```

### Log Management
```bash
# View all logs
docker compose logs

# Follow specific service logs
docker compose logs -f web
docker compose logs -f worker
```

## Backup Strategy

### Application Data
- **Files**: `./files/` directory (mapped volume)
- **Database**: External at 192.168.3.18 (handle separately)
- **Assets**: Docker volume `opdata`

### Backup Commands
```bash
# Backup uploaded files
tar -czf files-backup-$(date +%Y%m%d).tar.gz ./files/

# Backup Docker volumes
docker run --rm -v nimblepm_opdata:/data -v $(pwd):/backup ubuntu tar czf /backup/opdata-backup-$(date +%Y%m%d).tar.gz -C /data .
```

---

**Created**: $(date)
**Version**: 1.0
**Status**: Production Ready (pending final testing)