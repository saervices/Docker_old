# Collabora Online (CODE) Template

Collabora Online Development Edition (CODE) provides browser-based document editing for office files (Writer, Calc, Impress). It integrates with applications like Seafile or Nextcloud via the WOPI protocol.

## Requirements

- **Traefik** (or another reverse proxy) for TLS termination
- **Host application** (Seafile, Nextcloud) that supports WOPI integration
- Networks: `frontend` and `backend` must exist

## Architecture

This template uses **path-based routing** on the host application's domain. No separate subdomain or DNS record for Collabora is required.

```
Browser ──HTTPS──▶ seafile.example.com/browser/... ──Traefik──▶ collabora:9980
                   seafile.example.com/cool/...
                   seafile.example.com/hosting/discovery
```

| Network | Purpose |
|---------|---------|
| `frontend` | Traefik routes browser traffic to Collabora (required for office editing UI) |
| `backend` | Internal communication with host application (WOPI callbacks) |

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `COLLABORA_IMAGE` | Yes | `collabora/code` | Docker image reference |
| `TRAEFIK_HOST` | Yes | — | Traefik host rule (inherited from host app) |
| `COLLABORA_SERVER_NAME` | Yes | — | Public hostname (set by host app, e.g., `seafile.example.com`) |
| `COLLABORA_DICTIONARIES` | No | `en_US` | Space-separated spell-check dictionaries |
| `COLLABORA_EXTRA_PARAMS` | No | `--o:ssl.enable=false --o:ssl.termination=true` | Additional coolwsd parameters |

> **Note:** `aliasgroup1` (WOPI allowed hosts) is automatically derived as `https://${COLLABORA_SERVER_NAME}`.

### Traefik Routing

The template configures path-based routing using `TRAEFIK_HOST` (inherited from host app):

| Path Prefix | Description |
|-------------|-------------|
| `/hosting/discovery` | WOPI discovery endpoint |
| `/browser` | Collabora editor UI |
| `/cool` | Collabora WebSocket/API |
| `/lool` | Legacy endpoint (LibreOffice Online) |
| `/loleaflet` | Legacy editor assets |

## Seafile Integration

### 1. Add to x-required-services

In your Seafile `docker-compose.app.yaml`:

```yaml
x-required-services:
  - collabora
```

### 2. Configure Environment Variables

In your Seafile `.env`:

```bash
ENABLE_OFFICE_WEB_APP=true
COLLABORA_SERVER_NAME=seafile.example.com   # Same as SEAFILE_SERVER_HOSTNAME
```

### 3. Internal Discovery

Seafile uses internal Docker networking for WOPI discovery (server-to-server), configured in `docker-compose.app.yaml`:

```yaml
environment:
  COLLABORA_INTERNAL_URL: http://${APP_NAME}-collabora:9980
```

This is used in `seahub_settings_extra.py`:

```python
OFFICE_WEB_APP_BASE_URL = f'{_collabora_internal_url}/hosting/discovery'
```

## Security

| Setting | Value | Notes |
|---------|-------|-------|
| `cap_drop` | `ALL` | Drop all capabilities |
| `cap_add` | `SETUID, SETGID, CHOWN, FOWNER, MKNOD, SYS_CHROOT, SYS_ADMIN` | Minimum set for coolwsd sandbox |
| `no-new-privileges` | **not set** | coolforkit-caps requires file capabilities |
| `AppArmor` | `docker-default` | Mandatory confinement |
| `read_only` | **not set** | Collabora writes to `/opt/cool/`, `/etc/coolwsd/`, `/var/cache/` |
| `user` | **not set** | Collabora manages user switching internally (root -> cool) |

**Security Level:** Level 1+ (cap_drop ALL + minimal cap_add + AppArmor, but no-new-privileges disabled due to capability requirements)

## Health Check

The template uses the WOPI discovery endpoint:

```yaml
test: ["CMD-SHELL", "curl -sf http://localhost:9980/hosting/discovery > /dev/null || exit 1"]
interval: 30s
timeout: 10s
retries: 3
start_period: 30s
```

## Usage

### As a dependency (recommended)

Add to your app's `docker-compose.app.yaml`:

```yaml
x-required-services:
  - collabora
```

### Standalone

```bash
cd /mnt/data/Github/Docker
./get-folder.sh collabora
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `No acceptable WOPI host found` | Check that `COLLABORA_SERVER_NAME` matches your app's public URL (`aliasgroup1` is derived automatically) |
| Health check fails | Verify coolwsd started: `docker logs <container>` — check for capability errors |
| WebSocket errors | Traefik v2+ handles WebSocket upgrades automatically; check network connectivity |
| SSL errors in browser | Ensure `COLLABORA_EXTRA_PARAMS` includes `--o:ssl.enable=false --o:ssl.termination=true` |
| Blank editor iframe | Verify `SEAFILE_SERVER_HOSTNAME` matches the actual public domain |
| Discovery timeout | Check that Collabora container is on `backend` network and reachable from host app |
