# Redis Template

In-memory data store used for caching and session management across application stacks. Runs as non-root (`999:1000`) with a read-only root filesystem. Authentication via Docker secret.

---

## Configuration

| Variable | Default | Notes |
|----------|---------|-------|
| `REDIS_IMAGE` | `docker.io/library/redis:alpine` | Redis image tag. |
| `REDIS_PASSWORD_PATH` | `./secrets/` | Directory holding the Redis password file. |
| `REDIS_PASSWORD_FILENAME` | `REDIS_PASSWORD` | Secret file name. |

Edit `templates/redis/.env` before launching dependent services.

---

## Volumes & Secrets

- Named volume `redis` -> `/data` persists Redis state (AOF/Snapshot).
- Timezone files mounted read-only.
- Secret `REDIS_PASSWORD` -> `/run/secrets/REDIS_PASSWORD`, injected via the `command`:
  ```sh
  redis-server --save 60 1 --loglevel warning --requirepass "$(cat /run/secrets/REDIS_PASSWORD)"
  ```

---

## Security

- `user: 999:1000` (non-root)
- `read_only: true`
- `cap_drop: ALL`, no `cap_add` (no capabilities required)
- `no-new-privileges:true` + AppArmor confinement
- `init: true`, `stop_grace_period: 30s`, `oom_score_adj: -500`
- `tmpfs`: `/run`, `/tmp`

---

## Networking

Connected to `backend` network only. No Traefik labels (not publicly exposed).

---

## Healthcheck

```yaml
test: ['CMD-SHELL', 'redis-cli --pass "$(cat /run/secrets/REDIS_PASSWORD)" ping | grep PONG']
interval: 30s
timeout: 5s
retries: 3
start_period: 10s
```

---

## Maintenance Hints

- The container is fully read-only; extend tmpfs mounts if Redis modules require additional writable paths.
- No dependencies — Redis starts independently and other services depend on it.
- Make sure the consuming stack sets `APP_NAME` so container names are namespaced properly (e.g. `seafile-redis`).
