# Seafile Notification Server Template

Real-time push notification service for Seafile. Delivers instant file-change and sync-status updates to desktop and web clients over WebSocket connections. Lightweight Go binary with a read-only root filesystem.

---

## Configuration

| Variable | Default | Notes |
|----------|---------|-------|
| `SEAFILE_NOTIFICATION_SERVER_IMAGE` | `seafileltd/notification-server:13.0-latest` | Notification server image tag. |
| `APP_NAME` | **Required** | Must match the parent Seafile stack. |
| `APPARMOR_PROFILE` | `docker-default` | AppArmor profile. |

All other environment variables (database, Redis, JWT, server URL) are inherited from the parent Seafile app via a YAML anchor:

```yaml
environment: *seafile_common_environment
```

No separate `.env` entries are needed beyond the image tag.

---

## Volumes & Secrets

- Bind mount `./appdata/seafile/logs` -> `/shared/seafile/logs` stores the notification server log file.
- Timezone files mounted for clock synchronization.
- Secret `MARIADB_PASSWORD` is read inside the entrypoint:
  ```sh
  export SEAFILE_MYSQL_DB_PASSWORD="$(cat /run/secrets/MARIADB_PASSWORD)"
  exec /opt/seafile/notification-server -c /opt/seafile -l /shared/seafile/logs/notification-server.log
  ```
  The secret must be defined in the parent Seafile stack's `docker-compose.app.yaml`.

---

## Security

- `cap_drop: ALL` with minimal `cap_add`: `SETUID`, `SETGID`, `CHOWN`
- `no-new-privileges:true` + AppArmor confinement
- `read_only: true` (Go binary, no write requirements beyond logs and tmpfs)
- `init: true`, `stop_grace_period: 30s`, `oom_score_adj: -500`

---

## Networking & Traefik

Connected to both `frontend` and `backend` networks.

Traefik routes `/notification` to the container on port `8083`.

---

## Dependencies

Starts only after `mariadb`, `redis`, and `app` (Seafile) report healthy.

---

## Healthcheck

```yaml
test: ["CMD-SHELL", "bash -lc ': >/dev/tcp/127.0.0.1/8083'"]
interval: 30s
timeout: 10s
retries: 3
start_period: 10s
```

---

## Maintenance Hints

- Requires `ENABLE_NOTIFICATION_SERVER=true` in the parent Seafile app environment.
- The `JWT_PRIVATE_KEY` must be identical across the Seafile app, SeaDoc, and notification server.
- Log level is controlled via `NOTIFICATION_SERVER_LOG_LEVEL` in the parent stack (default: `info`).
- Unlike the SeaDoc server, this container **does** support `read_only: true` since it runs a single Go binary.
