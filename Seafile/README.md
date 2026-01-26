# Seafile Application Stack

Production-ready Docker Compose configuration for **Seafile** - a self-hosted file sync and share platform with enterprise features.

---

## Overview

Seafile is an open-source, self-hosted cloud storage solution with file synchronization, sharing, and team collaboration features. This stack includes the main Seafile server with optional notification server and SeaDoc collaborative document editor.

### Key Features

- File sync and share across devices
- Team collaboration with libraries and groups
- Version control and file locking
- Real-time notifications (optional)
- Collaborative document editing via SeaDoc (optional)
- Traefik reverse proxy integration
- Security-hardened container configuration

---

## Architecture

This stack deploys the following services:

| Service | Description |
|---------|-------------|
| `app` (Seafile) | Main Seafile server |
| `mariadb` | MySQL-compatible database |
| `redis` | Caching and session storage |
| `mariadb_maintenance` | Database backup/maintenance |
| `seafile_notification-server` | Real-time push notifications |
| `seafile_seadoc-server` | Collaborative document editor |

Dependencies are managed via `x-required-services`:

```yaml
x-required-services:
  - redis
  - mariadb
  - mariadb_maintenance
  - seafile_notification-server
  - seafile_seadoc-server
```

---

## Quick Start

### 1. Setup

```bash
# Navigate to Seafile directory
cd Docker/Seafile

# Run setup script to fetch templates and merge configurations
../run.sh Seafile
```

### 2. Configure Environment

Edit `.env` with your settings:

```bash
# Container image
IMAGE=seafileltd/seafile-mc:13.0-latest
APP_NAME=seafile

# Traefik routing
TRAEFIK_HOST=Host(`seafile.example.com`)
TRAEFIK_PORT=80

# Server configuration
SEAFILE_SERVER_PROTOCOL=https
SEAFILE_SERVER_HOSTNAME=seafile.example.com

# Admin credentials (first run only)
INIT_SEAFILE_ADMIN_EMAIL=admin@example.com
INIT_SEAFILE_ADMIN_PASSWORD=change-me-immediately

# JWT key (minimum 32 characters)
JWT_PRIVATE_KEY=your-generated-jwt-key-min-32-chars

# Optional features
ENABLE_NOTIFICATION_SERVER=true
ENABLE_SEADOC=true
```

### 3. Create Secrets

```bash
mkdir -p secrets

# Generate MariaDB password
pwgen -s 32 1 > secrets/MARIADB_PASSWORD

# Generate MariaDB root password
pwgen -s 32 1 > secrets/MARIADB_ROOT_PASSWORD

# Generate Redis password
pwgen -s 32 1 > secrets/REDIS_PASSWORD

# Set permissions
chmod 600 secrets/*
```

### 4. Generate JWT Key

```bash
# Option 1: Using pwgen
pwgen -s 40 1

# Option 2: Using openssl
openssl rand -base64 40
```

Add the generated key to `.env` as `JWT_PRIVATE_KEY`.

### 5. Start the Stack

```bash
docker compose -f docker-compose.main.yaml up -d
```

### 6. Access Seafile

Navigate to `https://seafile.example.com` and log in with the admin credentials.

---

## Configuration Reference

### Container Basics

| Variable | Default | Description |
|----------|---------|-------------|
| `IMAGE` | **Required** | Seafile Docker image |
| `APP_NAME` | **Required** | Container name prefix |
| `APP_UID` | `8000` | User ID inside container |
| `APP_GID` | `8000` | Group ID inside container |

### Traefik Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TRAEFIK_HOST` | **Required** | Traefik host rule |
| `TRAEFIK_PORT` | `80` | Internal container port |

### Server Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SEAFILE_SERVER_PROTOCOL` | `http` | Protocol (http/https) |
| `SEAFILE_SERVER_HOSTNAME` | **Required** | Server hostname |
| `JWT_PRIVATE_KEY` | **Required** | JWT secret (min 32 chars) |
| `TIME_ZONE` | `UTC` | Container timezone |
| `NON_ROOT` | `false` | Run as non-root user |

### Admin Configuration (First Run)

| Variable | Description |
|----------|-------------|
| `INIT_SEAFILE_ADMIN_EMAIL` | Admin email/username |
| `INIT_SEAFILE_ADMIN_PASSWORD` | Admin password |

### Database Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SEAFILE_MYSQL_DB_CCNET_DB_NAME` | `ccnet_db` | Ccnet database name |
| `SEAFILE_MYSQL_DB_SEAFILE_DB_NAME` | `seafile_db` | Seafile database name |
| `SEAFILE_MYSQL_DB_SEAHUB_DB_NAME` | `seahub_db` | Seahub database name |

### Optional Features

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_NOTIFICATION_SERVER` | `false` | Enable real-time notifications |
| `NOTIFICATION_SERVER_LOG_LEVEL` | `info` | Notification server log level |
| `ENABLE_SEADOC` | `false` | Enable SeaDoc document editor |
| `ENABLE_GO_FILESERVER` | `true` | Use Go-based file server |
| `SEAFILE_LOG_TO_STDOUT` | `true` | Send logs to stdout |

---

## Secrets

Required Docker secrets:

| Secret | Description |
|--------|-------------|
| `MARIADB_PASSWORD` | MariaDB user password |
| `MARIADB_ROOT_PASSWORD` | MariaDB root password (init only) |
| `REDIS_PASSWORD` | Redis password |

Secrets are injected via the custom entrypoint:

```yaml
entrypoint:
  - /bin/sh
  - -c
  - |
      export SEAFILE_MYSQL_DB_PASSWORD="$$(cat /run/secrets/MARIADB_PASSWORD)" \
            INIT_SEAFILE_MYSQL_ROOT_PASSWORD="$$(cat /run/secrets/MARIADB_ROOT_PASSWORD)" \
            REDIS_PASSWORD="$$(cat /run/secrets/REDIS_PASSWORD)"; \
      exec /sbin/my_init -- /scripts/enterpoint.sh
```

---

## Volume Mounts

| Host Path | Container Path | Description |
|-----------|---------------|-------------|
| `./appdata` | `/shared` | All Seafile data |

Subdirectories created automatically:
- `seafile-data/` - Library file blocks and metadata
- `seahub-data/` - Web UI assets (avatars, thumbnails)
- `conf/` - Configuration files
- `logs/` - Application logs (if not using stdout)

---

## Reverse Proxy Configuration

### Traefik Labels

The main app:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.${APP_NAME}-rtr.rule=${TRAEFIK_HOST}"
  - "traefik.http.services.${APP_NAME}-svc.loadBalancer.server.port=${TRAEFIK_PORT}"
```

Additional routes (when enabled):
- `/notification` → Notification Server (port 8083)
- `/sdoc-server`, `/socket.io` → SeaDoc Server (port 80)

---

## Security Features

### Hardening

- **No privilege escalation**: `no-new-privileges:true`
- **AppArmor confinement**: `apparmor=${APPARMOR_PROFILE:-docker-default}`
- **Docker secrets**: Credentials never in plain environment variables
- **Network isolation**: Separate `frontend` and `backend` networks
- **Init process**: `init: true` for proper signal handling
- **OOM protection**: `oom_score_adj: -500`

### Network Requirements

Create external networks before starting:

```bash
docker network create frontend
docker network create backend
```

---

## Healthcheck

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost:80 || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

---

## Troubleshooting

### Container Won't Start

Check dependencies:
```bash
docker ps --filter name=mariadb --filter name=redis
docker logs seafile-mariadb
docker logs seafile-redis
```

### Database Connection Failed

Verify secrets are readable:
```bash
docker exec seafile cat /run/secrets/MARIADB_PASSWORD
```

Check MariaDB is healthy:
```bash
docker exec seafile-mariadb mysql -u seafile -p -e "SELECT 1"
```

### Admin Login Failed

Reset admin password:
```bash
docker exec -it seafile /opt/seafile/seafile-server-latest/reset-admin.sh
```

### File Upload Issues

Check volume permissions:
```bash
ls -la ./appdata/
# Should be owned by UID/GID 8000
```

Fix permissions:
```bash
chown -R 8000:8000 ./appdata/
```

---

## Maintenance

### Viewing Logs

```bash
# All container logs
docker compose -f docker-compose.main.yaml logs -f

# Specific service
docker logs -f seafile
```

### Backup

Important paths to backup:

```bash
./appdata/              # All Seafile data
./secrets/              # Docker secrets
./.env                  # Configuration
```

### Database Backup

Use the `mariadb_maintenance` template for automated backups.

### Updates

```bash
# Update .env with new image version
IMAGE=seafileltd/seafile-mc:13.0-latest

# Pull and recreate
docker compose -f docker-compose.main.yaml pull
docker compose -f docker-compose.main.yaml up -d --force-recreate
```

### Garbage Collection

Clean orphaned blocks:
```bash
docker exec seafile /opt/seafile/seafile-server-latest/seaf-gc.sh
```

---

## Resource Requirements

### Minimum

- **CPU**: 2 cores
- **RAM**: 2 GB
- **Disk**: 20 GB (depends on usage)

### Recommended for Production

- **CPU**: 4+ cores
- **RAM**: 4-8 GB
- **Disk**: SSD recommended for database

---

## Version Information

- **Image**: `seafileltd/seafile-mc:13.0-latest`
- **Edition**: Community Edition (CE)
- **Port**: 80 (internal)

---

## Additional Resources

- [Seafile Official Documentation](https://manual.seafile.com/)
- [Docker Deployment Guide](https://manual.seafile.com/docker/deploy_seafile_with_docker/)
- [Seafile Admin Manual](https://manual.seafile.com/config/)
- [Seafile Forum](https://forum.seafile.com/)
