# Seafile Notification Server Template

Production-ready Docker Compose configuration for **Seafile Notification Server** - real-time push notifications for Seafile clients.

---

## Overview

The Notification Server delivers real-time push notifications to Seafile clients, enabling instant updates when files are modified, shared, or synced. It uses WebSocket connections to maintain persistent communication with clients.

### Key Features

- Real-time file change notifications
- WebSocket-based persistent connections
- Instant sync status updates for desktop/mobile clients
- Low-latency push notifications for library changes
- Secure credential injection via Docker secrets
- Hardened container configuration

---

## Prerequisites

Required services (declared via `depends_on`):

- **MariaDB** - Database backend (healthy)
- **Redis** - Caching and message queue (healthy)
- **Seafile App** - Main Seafile server instance (healthy)
- **Traefik** - Reverse proxy (optional but recommended)
- **Docker networks**: `frontend` and `backend` (external)

---

## Quick Start

### 1. Environment Configuration

Configure `.env`:

```bash
# Container image
SEAFILE_NOTIFICATION_SERVER_IMAGE=seafileltd/notification-server:13.0-latest

# Application name (must match your Seafile app name)
APP_NAME=seafile

# Security
APPARMOR_PROFILE=docker-default
```

### 2. Secrets Configuration

The MariaDB password is injected via Docker secrets. Ensure the secret is configured in the parent Seafile stack:

```yaml
secrets:
  MARIADB_PASSWORD:
    file: ./secrets/MARIADB_PASSWORD
```

### 3. Enable in Seafile

In your main Seafile `.env` file:

```bash
ENABLE_NOTIFICATION_SERVER=true
NOTIFICATION_SERVER_LOG_LEVEL=info
```

### 4. Start the Service

```bash
docker compose up -d
```

---

## Configuration Reference

### Environment Variables

This template uses YAML anchors to inherit environment variables from the main Seafile app:

```yaml
environment: *seafile_common_environment
```

Key variables inherited from the parent stack:

| Variable | Description |
|----------|-------------|
| `SEAFILE_MYSQL_DB_HOST` | MariaDB hostname |
| `SEAFILE_MYSQL_DB_USER` | Database user |
| `SEAFILE_MYSQL_DB_PASSWORD` | Injected from Docker secret |
| `REDIS_HOST` | Redis hostname |
| `REDIS_PORT` | Redis port (default: 6379) |
| `JWT_PRIVATE_KEY` | JWT secret for authentication |
| `SEAFILE_SERVER_PROTOCOL` | http or https |
| `SEAFILE_SERVER_HOSTNAME` | Server hostname |

### Template-Specific Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SEAFILE_NOTIFICATION_SERVER_IMAGE` | **Required** | Docker image for notification server |
| `APPARMOR_PROFILE` | `docker-default` | AppArmor security profile |

---

## Reverse Proxy Configuration

### Traefik Labels

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.${APP_NAME}_notification-server-rtr.rule=${TRAEFIK_HOST} && PathPrefix(`/notification`)"
  - "traefik.http.services.${APP_NAME}_notification-server-svc.loadBalancer.server.port=8083"
```

### Key Points

- **Path Prefix**: `/notification` routes to the notification server
- **Port**: Service listens on port `8083` internally
- **WebSocket**: Ensure your reverse proxy supports WebSocket upgrades

### Example URLs

If your Seafile domain is `seafile.example.com`:

- Notification endpoint: `https://seafile.example.com/notification/`

---

## Volume Mounts

| Host Path | Container Path | Mode | Description |
|-----------|---------------|------|-------------|
| `/etc/localtime` | `/etc/localtime` | `ro` | Sync container time with host |
| `/etc/timezone` | `/etc/timezone` | `rw` | Timezone information |
| `./appdata/seafile/logs` | `/shared/seafile/logs` | `rw` | Notification server logs |

---

## Security Features

### Hardening

- **Read-only filesystem**: `read_only: true`
- **Dropped capabilities**: `cap_drop: ALL`
- **No privilege escalation**: `no-new-privileges:true`
- **AppArmor confinement**: Enforced security profile
- **Docker secrets**: Password injected securely
- **Network isolation**: Separate `frontend` and `backend` networks

### Entrypoint Security

The container uses a custom entrypoint to securely inject the database password:

```yaml
entrypoint:
  - /bin/sh
  - -c
  - |
    export SEAFILE_MYSQL_DB_PASSWORD="$$(cat /run/secrets/MARIADB_PASSWORD)"; \
    exec /opt/seafile/notification-server -c /opt/seafile -l /shared/seafile/logs/notification-server.log
```

---

## Healthcheck

```yaml
healthcheck:
  test: ["CMD-SHELL", "bash -lc ': >/dev/tcp/127.0.0.1/8083'"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

Check health status:

```bash
docker ps --filter name=notification-server
docker inspect --format='{{.State.Health.Status}}' seafile_notification-server
```

---

## Dependencies

The service starts only after these dependencies are healthy:

```yaml
depends_on:
  mariadb:
    condition: service_healthy
  redis:
    condition: service_healthy
  app:
    condition: service_healthy
```

---

## Troubleshooting

### Container Won't Start

Check dependencies:
```bash
docker ps --filter name=mariadb --filter name=redis --filter name=seafile
```

Check logs:
```bash
docker logs seafile_notification-server
```

### Notifications Not Working

1. Verify `ENABLE_NOTIFICATION_SERVER=true` in Seafile config
2. Check Traefik routing:
   ```bash
   docker logs traefik | grep notification
   ```
3. Verify WebSocket connections in browser developer tools

### Connection Refused

Ensure the notification server URL matches your configuration:
```bash
# In Seafile container
echo $NOTIFICATION_SERVER_URL
echo $INNER_NOTIFICATION_SERVER_URL
```

---

## Integration with Seafile

The notification server integrates automatically when enabled. Key configuration in the main Seafile app:

```bash
# Enable notification server
ENABLE_NOTIFICATION_SERVER=true

# Client-facing URL (browser to notification server)
NOTIFICATION_SERVER_URL=https://seafile.example.com/notification

# Internal URL (Seafile to notification server)
INNER_NOTIFICATION_SERVER_URL=http://seafile_notification-server:8083
```

---

## Maintenance

### Viewing Logs

```bash
# Container logs
docker logs -f seafile_notification-server

# Application logs
tail -f ./appdata/seafile/logs/notification-server.log
```

### Updates

```bash
# Pull latest image
docker pull seafileltd/notification-server:13.0-latest

# Recreate container
docker compose up -d --force-recreate
```

---

## Resource Requirements

### Minimum

- **CPU**: 0.5 cores
- **RAM**: 128 MB
- **Disk**: Minimal (logs only)

### Recommended for Production

- **CPU**: 1 core
- **RAM**: 256-512 MB

---

## Version Information

- **Image**: `seafileltd/notification-server:13.0-latest`
- **Port**: 8083
- **Supported Seafile versions**: 11.0+

---

## Additional Resources

- [Seafile Official Documentation](https://manual.seafile.com/)
- [Notification Server Setup](https://manual.seafile.com/docker/deploy_seafile_with_docker/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
