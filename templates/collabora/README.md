# Collabora Online (CODE) Template

Collabora Online Development Edition (CODE) provides browser-based document editing for office files (Writer, Calc, Impress). It integrates with applications like Seafile or Nextcloud via the WOPI protocol.

## Requirements

- **Own domain/subdomain** for Collabora (e.g., `office.example.com`) — cannot share the app's domain with a path prefix
- **Traefik** (or another reverse proxy) for TLS termination
- **DNS record** pointing the Collabora domain to your server

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `COLLABORA_IMAGE` | Yes | `collabora/code:latest` | Docker image reference |
| `COLLABORA_HOST` | Yes | — | Traefik router rule, e.g., `Host(\`office.example.com\`)` |
| `COLLABORA_SERVER_NAME` | Yes | — | Public hostname (must match `COLLABORA_HOST`) |
| `COLLABORA_ALIASGROUP1` | Yes | — | Allowed WOPI host URL (regex-escaped, e.g., `https://seafile\\.example\\.com`) |
| `COLLABORA_DICTIONARIES` | No | `en_US` | Space-separated spell-check dictionaries |
| `COLLABORA_EXTRA_PARAMS` | No | `--o:ssl.enable=false --o:ssl.termination=true` | Additional coolwsd parameters |

### Seafile Integration (WOPI)

Add to your `seahub_settings_extra.py` (or equivalent configuration):

```python
ENABLE_OFFICE_WEB_APP = True
OFFICE_WEB_APP_BASE_URL = 'https://office.example.com/hosting/capabilities'
OFFICE_WEB_APP_NAME = 'Collabora Online'
OFFICE_WEB_APP_FILE_EXTENSION = ('ods', 'xls', 'xlsb', 'xlsm', 'xlsx', 'ppsx', 'ppt', 'pptm', 'pptx', 'doc', 'docm', 'docx')
OFFICE_WEB_APP_EDIT_FILE_EXTENSION = ('ods', 'xls', 'xlsb', 'xlsm', 'xlsx', 'ppsx', 'ppt', 'pptm', 'pptx', 'doc', 'docm', 'docx')
```

## Security

| Setting | Value | Notes |
|---------|-------|-------|
| `cap_drop` | `ALL` | Drop all capabilities |
| `cap_add` | `SETUID, SETGID, CHOWN, FOWNER, MKNOD, SYS_CHROOT` | Minimum set for coolwsd sandbox |
| `no-new-privileges` | `true` | Prevent privilege escalation |
| `AppArmor` | `docker-default` | Mandatory confinement |
| `read_only` | **not set** | Collabora writes to `/opt/cool/`, `/etc/coolwsd/`, `/var/cache/` |
| `user` | **not set** | Collabora manages user switching internally (root -> cool) |

**Security Level:** Level 2 (cap_drop ALL + minimal cap_add + no-new-privileges + AppArmor)

## Health Check

The template uses the WOPI discovery endpoint:
```
GET http://localhost:9980/hosting/discovery
```

## Network Architecture

- **frontend** — Traefik routes external traffic to Collabora (port 9980)
- **backend** — Available for internal communication with application services

## Usage

### As a dependency (x-required-services)

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
| `No acceptable WOPI host found` | Check `COLLABORA_ALIASGROUP1` matches your app's public URL (escape dots with `\\.`) |
| Health check fails | Verify coolwsd started: `docker logs <container>` — check for capability errors |
| WebSocket errors | Enable `websocket-security-headers@file` middleware in Traefik labels |
| SSL errors in browser | Ensure `COLLABORA_EXTRA_PARAMS` includes `--o:ssl.enable=false --o:ssl.termination=true` |
| Blank editor iframe | Verify DNS for `COLLABORA_SERVER_NAME` resolves correctly and Traefik routes traffic |
