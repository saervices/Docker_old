# Seafile SeaDoc Server Template

Production-ready Docker Compose configuration for **Seafile SeaDoc Server** - a collaborative online document editor for Seafile.

---

## Overview

SeaDoc Server is Seafile's built-in collaborative document editor that enables real-time collaborative editing of documents, spreadsheets, and presentations. It integrates directly with your Seafile instance to provide Office-like editing capabilities.

### Key Features

- Real-time collaborative document editing
- Support for documents, spreadsheets, and presentations
- WebSocket-based real-time synchronization
- Direct integration with Seafile file storage
- JWT-based authentication
- Reverse proxy ready (Traefik configuration included)

---

## Prerequisites

Required services:

- **MariaDB** - Database backend
- **Redis** - Caching and session storage
- **Seafile App** - Main Seafile server instance
- **Traefik** - Reverse proxy (optional but recommended)
- **Docker networks**: `frontend` and `backend`

---

## Quick Start

### 1. Environment Configuration

Configure the essential variables in `.env`:

```bash
# Container image
SEAFILE_SEADOC_SERVER_IMAGE=seafileltd/sdoc-server:2.0-latest

# Application name (must match your Seafile app name)
APP_NAME=seafile

# Traefik configuration
TRAEFIK_HOST=Host(`seafile.example.com`)

# Security
APPARMOR_PROFILE=docker-default

# Seafile Server Configuration
SEAFILE_SERVER_PROTOCOL=https
SEAFILE_SERVER_HOSTNAME=seafile.example.com

# Database Configuration
SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=seahub_db

# JWT Authentication (REQUIRED - minimum 32 characters)
JWT_PRIVATE_KEY=your-generated-jwt-key-min-32-chars

# Timezone
TIME_ZONE=UTC

# Non-root mode
NON_ROOT=false
```

### 2. Generate JWT Private Key

Generate a secure JWT private key (minimum 32 characters):

```bash
# Option 1: Using pwgen
pwgen -s 40 1

# Option 2: Using openssl
openssl rand -base64 40

# Option 3: Using /dev/urandom
tr -dc 'A-Za-z0-9' </dev/urandom | head -c 40; echo
```

Copy the generated key to your `.env` file as `JWT_PRIVATE_KEY`.

### 3. Secrets Configuration

The MariaDB password is injected via Docker secrets. Ensure your secret is configured in the parent `docker-compose.app.yaml`:

```yaml
secrets:
  MARIADB_PASSWORD:
    file: ./secrets/MARIADB_PASSWORD
```

Create the secret file:

```bash
mkdir -p secrets
echo "your-secure-mariadb-password" > secrets/MARIADB_PASSWORD
chmod 600 secrets/MARIADB_PASSWORD
```

### 4. Start the Service

```bash
docker compose up -d
```

---

## Configuration Reference

### Environment Variables

#### Container Basics

| Variable | Default | Description |
|----------|---------|-------------|
| `SEAFILE_SEADOC_SERVER_IMAGE` | `seafileltd/sdoc-server:2.0-latest` | Docker image for SeaDoc Server |
| `APP_NAME` | **Required** | Application name (must match Seafile app) |

#### Database Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | `${APP_NAME}-mariadb` | MariaDB host (auto-configured) |
| `DB_USER` | `${APP_NAME}` | Database user (matches app name) |
| `DB_NAME` | `seahub_db` | Database name for Seahub |
| `DB_PASSWORD` | - | Injected from Docker secret |

#### Seafile Server Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SEAFILE_SERVER_PROTOCOL` | `http` | Protocol (http/https) |
| `SEAFILE_SERVER_HOSTNAME` | **Required** | Seafile server hostname |
| `SEAHUB_SERVICE_URL` | Auto-generated | Full Seafile URL (protocol + hostname) |

#### Security & Authentication

| Variable | Default | Description |
|----------|---------|-------------|
| `JWT_PRIVATE_KEY` | **Required** | JWT secret key (min 32 chars) |
| `NON_ROOT` | `false` | Run container as non-root user |
| `APPARMOR_PROFILE` | `docker-default` | AppArmor security profile |

#### System Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TIME_ZONE` | `UTC` | Container timezone |

#### Traefik Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TRAEFIK_HOST` | **Required** | Traefik host rule (e.g., `Host(\`seafile.example.com\`)`) |

---

## Reverse Proxy Configuration

### Traefik Labels

The service is configured with the following Traefik routing:

```yaml
labels:
  # Enable Traefik routing
  - "traefik.enable=true"

  # Router rule: Match host AND specific paths
  - "traefik.http.routers.${APP_NAME}_seadoc-server-rtr.rule=${TRAEFIK_HOST} && (PathPrefix(`/sdoc-server`) || PathPrefix(`/socket.io`))"

  # Internal container port
  - "traefik.http.services.${APP_NAME}_seadoc-server-svc.loadBalancer.server.port=80"

  # Middleware: Strip /sdoc-server prefix
  - "traefik.http.middlewares.${APP_NAME}_seadoc-server-middlewares.stripprefix.prefixes=/sdoc-server"
```

### Key Points

- **Path Prefixes**: SeaDoc Server is accessible at:
  - `/sdoc-server/*` - Main document editor interface
  - `/socket.io/*` - WebSocket for real-time collaboration

- **Strip Prefix**: The `/sdoc-server` prefix is stripped before forwarding to the container

- **WebSocket Support**: The `/socket.io` path is essential for real-time collaboration features

### Example URLs

If your Seafile domain is `seafile.example.com`:

- SeaDoc Editor: `https://seafile.example.com/sdoc-server/`
- WebSocket: `https://seafile.example.com/socket.io/`

---

## Volume Mounts

| Host Path | Container Path | Mode | Description |
|-----------|---------------|------|-------------|
| `/etc/localtime` | `/etc/localtime` | `ro` | Sync container time with host |
| `/etc/timezone` | `/etc/timezone` | `rw` | Timezone information |
| `./appdata/seadoc` | `/shared` | `rw` | SeaDoc Server data and logs |

---

## Dependencies

The service will only start after these dependencies are healthy:

```yaml
depends_on:
  mariadb:
    condition: service_healthy
  redis:
    condition: service_healthy
  app:
    condition: service_healthy
```

Ensure all parent services define proper health checks.

---

## Healthcheck

The container includes an automatic health check:

```yaml
healthcheck:
  test: ["CMD-SHELL", "bash -lc ': >/dev/tcp/127.0.0.1/80'"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

Check health status:

```bash
docker ps --filter name=seadoc-server
docker inspect --format='{{.State.Health.Status}}' <container-name>
```

---

## Security Considerations

### Hardening Features

- **No privilege escalation**: `security_opt: no-new-privileges:true`
- **AppArmor confinement**: Enforced security profile
- **Non-root option**: Set `NON_ROOT=true` for enhanced security
- **Docker secrets**: Database password injected securely
- **Network isolation**: Separate `frontend` and `backend` networks

### Security Best Practices

1. **Generate a strong JWT key**: Use at least 40 random characters
2. **Rotate secrets regularly**: Update `JWT_PRIVATE_KEY` and database passwords periodically
3. **Use HTTPS**: Always set `SEAFILE_SERVER_PROTOCOL=https` in production
4. **Restrict network access**: Use Docker networks to isolate services
5. **Monitor logs**: Check `./appdata/seadoc/` for security events

---

## Troubleshooting

### Container Won't Start

Check dependencies:
```bash
docker ps --filter name=mariadb --filter name=redis --filter name=seafile
```

Check logs:
```bash
docker logs <container-name>
```

### Connection Issues

Verify database connection:
```bash
docker exec -it <container-name> bash
mysql -h ${DB_HOST} -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME}
```

Check JWT configuration:
Ensure `JWT_PRIVATE_KEY` is set and matches your Seafile configuration.

### WebSocket Connection Fails

Verify Traefik routing:
```bash
docker logs traefik | grep seadoc-server
```

Ensure:
- `/socket.io` path is properly routed
- WebSocket upgrades are enabled in Traefik
- HTTPS is configured correctly

Check SeaDoc logs:
```bash
tail -f ./appdata/seadoc/logs/*.log
```

---

## Integration with Seafile

### Seafile Configuration

Add the following to your Seafile `seahub_settings.py`:

```python
# SeaDoc Server configuration
SEADOC_SERVER_URL = 'https://seafile.example.com/sdoc-server'

# JWT configuration (must match JWT_PRIVATE_KEY)
SEADOC_JWT_PRIVATE_KEY = 'your-jwt-private-key-here'
```

Restart your Seafile server after making changes:

```bash
docker restart seafile-app
```

### Testing Integration

1. Log into Seafile web interface
2. Create or open a supported document (.docx, .xlsx, .pptx, .odt, .ods, .odp)
3. The document should open in SeaDoc Editor
4. Test real-time collaboration by opening the same document in multiple browser tabs

---

## Maintenance

### Viewing Logs

```bash
# Container logs
docker logs -f <container-name>

# Application logs
tail -f ./appdata/seadoc/logs/*.log
```

### Backup

Important paths to backup:

```bash
./appdata/seadoc/     # SeaDoc Server data and configuration
./secrets/            # Docker secrets (encrypted storage recommended)
```

### Updates

```bash
# Pull latest image
docker pull seafileltd/sdoc-server:2.0-latest

# Recreate container
docker compose up -d --force-recreate
```

### Cleanup

```bash
# Remove old logs
find ./appdata/seadoc/logs/ -name "*.log" -mtime +30 -delete

# Clean old Docker images
docker image prune -a
```

---

## Resource Requirements

### Minimum Requirements

- **CPU**: 1 core
- **RAM**: 512 MB
- **Disk**: 2 GB for application data

### Recommended for Production

- **CPU**: 2 cores
- **RAM**: 1-2 GB
- **Disk**: 10 GB+ (depends on document usage)

---

## Version Information

- **Image**: `seafileltd/sdoc-server:2.0-latest`
- **Base**: Seafile official Docker image
- **Supported Seafile versions**: 11.0+

---

## Additional Resources

- [Seafile Official Documentation](https://manual.seafile.com/)
- [SeaDoc Server Documentation](https://manual.seafile.com/docker/deploy_seafile_with_docker/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

---

## License

This template follows the Docker Compose template structure from the parent repository. Seafile and SeaDoc Server are licensed under their respective licenses.
