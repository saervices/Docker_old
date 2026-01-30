# SeaDoc Server Template

Collaborative online document editor for Seafile. Provides real-time editing via WebSocket (`/socket.io`) and serves the editor UI under `/sdoc-server`. Based on the `phusion/baseimage` init system.

---

## Configuration

| Variable | Default | Notes |
|----------|---------|-------|
| `SEAFILE_SEADOC_SERVER_IMAGE` | `seafileltd/sdoc-server:2.0-latest` | SeaDoc image tag. |
| `APP_NAME` | **Required** | Must match the parent Seafile stack. |
| `SEAFILE_SERVER_PROTOCOL` | `http` | Protocol for `SEAHUB_SERVICE_URL`. |
| `SEAFILE_SERVER_HOSTNAME` | **Required** | Hostname for `SEAHUB_SERVICE_URL`. |
| `SEAFILE_MYSQL_DB_SEAHUB_DB_NAME` | `seahub_db` | Seahub database name. |
| `JWT_PRIVATE_KEY` | **Required** | Shared JWT secret (min 32 chars). Must match the main Seafile app. |
| `NON_ROOT` | `false` | Run as non-root (currently buggy in v13, see below). |
| `TIME_ZONE` | `UTC` | Container timezone. |
| `APPARMOR_PROFILE` | `docker-default` | AppArmor profile. |

Edit `templates/seafile_seadoc-server/.env` or the parent stack `.env` before launching.

---

## Volumes & Secrets

- Bind mount `./appdata/seadoc` -> `/shared` stores SeaDoc data and logs.
- Timezone files mounted for clock synchronization.
- Secret `MARIADB_PASSWORD` is read inside the entrypoint:
  ```sh
  export DB_PASSWORD="$(cat /run/secrets/MARIADB_PASSWORD)"
  ```
  The secret must be defined in the parent Seafile stack's `docker-compose.app.yaml`.

---

## Security

- `cap_drop: ALL` with minimal `cap_add`: `SETUID`, `SETGID`, `CHOWN`, `DAC_OVERRIDE`
- `no-new-privileges:true` + AppArmor confinement
- `read_only` is **not** enabled (baseimage-docker is incompatible)
- `init: true`, `stop_grace_period: 30s`, `oom_score_adj: -500`

---

## Networking & Traefik

Connected to both `frontend` and `backend` networks.

Traefik routes two path prefixes to the container (port `80`):

| Path | Purpose |
|------|---------|
| `/sdoc-server/*` | Editor UI (prefix stripped before forwarding) |
| `/socket.io/*` | WebSocket for real-time collaboration |

---

## Dependencies

Starts only after `mariadb`, `redis`, and `app` (Seafile) report healthy.

---

## Healthcheck

```yaml
test: ["CMD-SHELL", "bash -lc ': >/dev/tcp/127.0.0.1/80'"]
interval: 30s
timeout: 10s
retries: 3
start_period: 10s
```

---

## Maintenance Hints

- The container uses `phusion/baseimage` (`/sbin/my_init`), which is **not** compatible with `read_only: true`.
- The `NON_ROOT` feature in Seafile v13.0.15 is buggy (missing execute permissions on internal scripts). Use root with minimal capabilities instead.
- SeaDoc requires `ENABLE_SEADOC=true` in the parent Seafile app environment to be activated.
- The `JWT_PRIVATE_KEY` must be identical across the Seafile app, SeaDoc, and notification server.
