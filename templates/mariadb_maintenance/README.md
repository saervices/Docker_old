# MariaDB Maintenance Template

Companion container for automated MariaDB backups (via Supercronic) and on-demand restores. Builds a custom image from `dockerfiles/dockerfile.supersonic.mariadb`. Runs as non-root (`999:999`) with a read-only root filesystem. Shares the `database` volume and secrets with the primary MariaDB container via YAML anchors.

---

## Configuration

| Variable | Default | Notes |
|----------|---------|-------|
| `MARIADB_BACKUP_RETENTION_DAYS` | `7` | Delete backups older than N days. |
| `MARIADB_BACKUP_DEBUG` | `false` | Verbose logging for backup script. |
| `MARIADB_RESTORE_DRY_RUN` | `false` | Simulate restore without copying data back. |
| `MARIADB_RESTORE_DEBUG` | `false` | Verbose logging for restore path. |

Edit `templates/mariadb_maintenance/.env` to adjust defaults.

---

## Backup

`/usr/local/bin/backup.sh [full|incremental|dump]`

| Mode | Tool | Description |
|------|------|-------------|
| `full` (default) | `mariadb-backup` | Physical backup, compressed with `zstd`. |
| `incremental` | `mariadb-backup` | Incremental on top of the last full backup. |
| `dump` | `mariadb-dump` | Logical SQL export, compressed with `zstd`. |

Backups are stored under `/backup/<YYYYMMDD>/` with descriptive filenames (e.g. `full_20240915_01.zst`).

### Default Schedule (`scripts/backup.cron`)

| Schedule | Command |
|----------|---------|
| Daily at midnight | `backup.sh full` |
| Every hour on the hour | `backup.sh incremental` |
| _(disabled)_ Every hour at :05 | `backup.sh dump` |

---

## Restore

1. Stop the primary MariaDB service (no process may be using `/var/lib/mysql`).
2. Place backup archives in `./restore/` (full + incrementals as needed).
3. Start the maintenance container — `docker-entrypoint.sh` detects the files, prepares and copies data back into `/var/lib/mysql`.
4. After completion, the `restore/` directory is cleaned up.

Set `MARIADB_RESTORE_DRY_RUN=true` to validate without applying changes.

Restores fail fast if the database is still reachable or if the filesystem is read-only. Disable `read_only` temporarily in the compose file when running a real restore.

---

## Volumes & Secrets

- Named volume `database` -> `/var/lib/mysql` (shared with primary MariaDB container)
- `./backup` -> `/backup` stores backup artifacts
- `./restore` -> `/restore` drop zone for restore archives
- Timezone files mounted read-only
- Secrets inherited from primary MariaDB via YAML anchor (`*mariadb_common_secrets`):
  - `MARIADB_PASSWORD` -> `/run/secrets/MARIADB_PASSWORD`
  - `MARIADB_ROOT_PASSWORD` -> `/run/secrets/MARIADB_ROOT_PASSWORD`

### Environment

| Variable | Value | Notes |
|----------|-------|-------|
| `MARIADB_USER` | `${APP_NAME}` | Application database user. |
| `MARIADB_DATABASE` | `${APP_NAME}` | Default database name. |
| `MARIADB_DB_HOST` | `${APP_NAME}-mariadb` | Primary MariaDB container hostname. |
| `MARIADB_PASSWORD_FILE` | `/run/secrets/MARIADB_PASSWORD` | Secret injection. |
| `MARIADB_ROOT_PASSWORD_FILE` | `/run/secrets/MARIADB_ROOT_PASSWORD` | Root secret injection. |

---

## Security

- `user: 999:999` (non-root)
- `read_only: true`
- `cap_drop: ALL` with minimal `cap_add`: `SETUID`, `SETGID`, `CHOWN`
- `no-new-privileges:true` + AppArmor confinement
- `init: true`, `stop_grace_period: 30s`, `oom_score_adj: -500`
- Backups written with `umask 077`

---

## Networking

Connected to `backend` network only. No Traefik labels (not publicly exposed).

---

## Healthcheck

```yaml
test: ["CMD", "sh", "-c", "pgrep supercronic >/dev/null 2>&1"]
interval: 30s
timeout: 5s
retries: 3
start_period: 10s
```

---

## File Layout

| Path | Description |
|------|-------------|
| `docker-compose.mariadb_maintenance.yaml` | Service definition (builds custom image). |
| `dockerfiles/dockerfile.supersonic.mariadb` | Dockerfile adding Supercronic + backup tools. |
| `scripts/backup.sh` | Backup entrypoint (full/incremental/dump). |
| `scripts/docker-entrypoint.sh` | Restore orchestration, then launches Supercronic. |
| `scripts/backup.cron` | Cron schedule (customizable via bind mount). |

---

## Maintenance Hints

- The container runs fully read-only; only `/backup`, `/restore`, and the MariaDB data volume are writable.
- Customize the backup schedule by bind-mounting your own `backup.cron` file.
- Incremental backups depend on the latest full backup — always retain at least one recent full archive.
- No explicit `depends_on` — the container can start independently, but `MARIADB_DB_HOST` must be reachable for backups to succeed.
