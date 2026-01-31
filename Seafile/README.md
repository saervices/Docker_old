# Seafile Application Stack

Self-hosted file sync and share platform with SSO authentication (Authentik), real-time notifications, and collaborative document editing (SeaDoc). Uses MariaDB and Redis as backing services.

---

## Architecture

```yaml
x-required-services:
  - redis
  - mariadb
  - mariadb_maintenance
  - seafile_notification-server
  - seafile_seadoc-server
```

| Service | Description |
|---------|-------------|
| `app` | Main Seafile server (based on `phusion/baseimage`) |
| `mariadb` | MariaDB database (template) |
| `redis` | Redis cache (template) |
| `mariadb_maintenance` | Automated database backup/restore (template) |
| `seafile_notification-server` | Real-time push notifications (template) |
| `seafile_seadoc-server` | Collaborative document editor (template) |

---

## Configuration

### Container Basics

| Variable | Default | Notes |
|----------|---------|-------|
| `IMAGE` | `seafileltd/seafile-mc:13.0-latest` | Seafile Community Edition image. |
| `APP_NAME` | `seafile` | Container name prefix for all services. |
| `APP_UID` / `APP_GID` | `8000` | UID/GID for volume ownership. |
| `TRAEFIK_HOST` | **Required** | Traefik host rule (e.g. `Host(\`seafile.example.com\`)`). |
| `TRAEFIK_PORT` | `80` | Internal container port. |
| `SEAFILE_DATA_PATH` | `./appdata/seafile/seafile-data` | Library data storage path. See [Separating Library Data Storage](#separating-library-data-storage). |

### Server Settings

| Variable | Default | Notes |
|----------|---------|-------|
| `SEAFILE_SERVER_PROTOCOL` | `https` | Protocol (http/https). |
| `SEAFILE_SERVER_HOSTNAME` | **Required** | Server hostname. |
| `JWT_PRIVATE_KEY` | **Required** | Shared JWT secret (min 32 chars). Identical across app, SeaDoc, and notification server. |
| `NON_ROOT` | `false` | Buggy in v13.0.15, keep `false`. |
| `ENABLE_GO_FILESERVER` | `true` | Go-based file server for better performance. |
| `SEAFILE_LOG_TO_STDOUT` | `true` | Send logs to stdout instead of files. |

### Admin (First Run Only)

| Variable | Notes |
|----------|-------|
| `INIT_SEAFILE_ADMIN_EMAIL` | Admin email/username. |
| `INIT_SEAFILE_ADMIN_PASSWORD` | Admin password (change immediately). |

### Optional Features

| Variable | Default | Notes |
|----------|---------|-------|
| `ENABLE_NOTIFICATION_SERVER` | `true` | Real-time notifications. |
| `NOTIFICATION_SERVER_LOG_LEVEL` | `info` | Notification server log level. |
| `ENABLE_SEADOC` | `true` | Collaborative document editor. |
| `ENABLE_SEAFDAV` | `true` | WebDAV access via `/seafdav`. |

### OAuth / Authentik

| Variable | Default | Notes |
|----------|---------|-------|
| `OAUTH_PROVIDER_DOMAIN` | **Required** | Authentik URL (e.g. `https://authentik.example.com`). |

OAuth settings (client ID/secret, attribute mapping, SSO redirect) are configured in `scripts/seahub_settings_extra.py`, not via environment variables. See [Extra Settings](#extra-settings-injection) below.

### Upload Limits

| Variable | Default | Notes |
|----------|---------|-------|
| `MAX_UPLOAD_FILE_SIZE` | `0` | Max upload size in MB (`0` = unlimited). |
| `MAX_NUMBER_OF_FILES_FOR_FILEUPLOAD` | `0` | Max files per upload (`0` = unlimited). |

---

## Secrets

| Secret | Description |
|--------|-------------|
| `MARIADB_PASSWORD` | MariaDB user password. |
| `MARIADB_ROOT_PASSWORD` | MariaDB root password (initial setup). |
| `REDIS_PASSWORD` | Redis authentication password. |
| `OAUTH_CLIENT_ID` | Authentik OAuth client ID. |
| `OAUTH_CLIENT_SECRET` | Authentik OAuth client secret. |

All secrets are injected via the entrypoint using `cat /run/secrets/<NAME>`. Generate passwords with:

```bash
../run.sh Seafile --generate_password
```

---

## Extra Settings Injection

Custom Seahub settings (OAuth, security hardening, session policy, etc.) are managed in `scripts/seahub_settings_extra.py`, which is bind-mounted read-only into the container:

```yaml
- ./scripts/seahub_settings_extra.py:/shared/seafile/conf/seahub_settings_extra.py:ro
- ./scripts/inject_extra_settings.sh:/usr/local/bin/inject_extra_settings.sh:ro
```

On startup, `inject_extra_settings.sh` appends the following to `seahub_settings.py` if not already present:

```python
from seahub_settings_extra import *
```

This approach keeps custom settings separate from the auto-generated `seahub_settings.py` and survives container rebuilds.

### Settings Managed in `seahub_settings_extra.py`

- **OAuth/Authentik**: Provider URLs, client credentials (via Docker secrets), attribute mapping, SSO redirects
- **SSO Policy**: Password login disabled, client SSO via browser, app-specific passwords, logout redirect
- **Access Control**: Global address book, cloud mode, account deletion, profile editing, watermark
- **Session Security**: Browser close expiry, cookie age, save-every-request
- **Password Policy**: Min length, strength level, strong password enforcement
- **WebDAV Policy**: Secret min length, strength level
- **Share Links**: Force password, min length, strength level, max expiration
- **CSRF/Cookies**: Trusted origins, SameSite strict, secure flags
- **Django Security**: Allowed hosts
- **Upload Limits**: File size, file count (via env vars)
- **Encryption**: Library password length, encryption version
- **Site Customization**: Language, site name, site title
- **Admin**: Web UI settings disabled (config-as-code)

---

## Volumes

| Host Path | Container Path | Mode | Description |
|-----------|---------------|------|-------------|
| `./appdata` | `/shared` | `rw` | All Seafile data (libraries, config, logs). |
| `./scripts/seahub_settings_extra.py` | `/shared/seafile/conf/seahub_settings_extra.py` | `ro` | Custom Seahub settings. |
| `./scripts/inject_extra_settings.sh` | `/usr/local/bin/inject_extra_settings.sh` | `ro` | Settings injector script. |

Subdirectories created automatically under `./appdata`:
- `seafile-data/` — Library file blocks and metadata (the bulk of storage)
- `seahub-data/` — Web UI assets (avatars, thumbnails)
- `conf/` — Configuration files
- `logs/` — Application logs (if not using stdout)

### Separating Library Data Storage

By default, all data lives under `./appdata`. After initial setup, you can move the library data (`seafile-data/`) to a separate location (e.g., a different disk, ZFS dataset, or NFS mount).

**Requirements:**
- Seafile must have completed initial setup first (directories and database schema created)
- The stack must be stopped during migration

**Steps:**

1. Stop the stack:
   ```bash
   docker compose -f docker-compose.main.yaml down
   ```

2. Move the data to the new location:
   ```bash
   mv ./appdata/seafile/seafile-data /mnt/storage/seafile-data
   ```

3. Set `SEAFILE_DATA_PATH` in `.env`:
   ```bash
   SEAFILE_DATA_PATH=/mnt/storage/seafile-data
   ```

4. Uncomment the volume mount in `docker-compose.app.yaml`:
   ```yaml
   - ${SEAFILE_DATA_PATH:-./appdata/seafile/seafile-data}:/shared/seafile/seafile-data:rw
   ```

5. Start the stack:
   ```bash
   docker compose -f docker-compose.main.yaml up -d
   ```

> **Important:** Do NOT enable the separate volume mount before the initial setup. Seafile needs the unified `./appdata:/shared` mount during first run to create its directory structure and configuration files. The separate mount overlays the path created by the base mount, so enabling it on a fresh install results in an empty `seafile-data/` directory that Seafile cannot initialize correctly.

---

## Security

- `cap_drop: ALL` with minimal `cap_add`: `SETUID`, `SETGID`, `CHOWN`, `DAC_OVERRIDE`
- `no-new-privileges:true` + AppArmor confinement
- `read_only` is **not** enabled (baseimage-docker is incompatible)
- `init: true`, `stop_grace_period: 30s`, `oom_score_adj: -500`
- Separate `frontend` and `backend` networks

---

## Networking & Traefik

| Route | Service | Port |
|-------|---------|------|
| `${TRAEFIK_HOST}` | `app` | `80` |
| `${TRAEFIK_HOST} && PathPrefix(\`/notification\`)` | `notification-server` | `8083` |
| `${TRAEFIK_HOST} && (PathPrefix(\`/sdoc-server\`) \|\| PathPrefix(\`/socket.io\`))` | `seadoc-server` | `80` |

---

## Dependencies

The `app` service starts after `mariadb` and `redis` report healthy. The `notification-server` and `seadoc-server` additionally wait for `app` to be healthy.

---

## Healthcheck

```yaml
test: ["CMD-SHELL", "curl -f http://localhost:80 || exit 1"]
interval: 30s
timeout: 10s
retries: 3
start_period: 10s
```

---

## Maintenance

### Database Backup

Handled by the `mariadb_maintenance` template. See `templates/mariadb_maintenance/README.md`.

### Garbage Collection

Clean orphaned file blocks:

```bash
docker exec seafile /opt/seafile/seafile-server-latest/seaf-gc.sh
```

### Admin Password Reset

```bash
docker exec -it seafile /opt/seafile/seafile-server-latest/reset-admin.sh
```

### Updates

Update the `IMAGE` variable in `.env`, then:

```bash
docker compose -f docker-compose.main.yaml pull
docker compose -f docker-compose.main.yaml up -d
```

---

## Additional Resources

- [Seafile Admin Manual](https://manual.seafile.com/)
- [Docker Deployment Guide](https://manual.seafile.com/docker/deploy_seafile_with_docker/)
- [Seahub Settings Reference](https://manual.seafile.com/config/seahub_settings_py/)
- [Seafile Forum](https://forum.seafile.com/)
