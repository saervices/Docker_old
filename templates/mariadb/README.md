# MariaDB Template

Reusable MariaDB service definition with opinionated performance tuning and security defaults. Runs as non-root (`999:999`) with a read-only root filesystem. Passwords are injected via Docker secrets using the `_FILE` suffix pattern.

---

## Configuration

### Container & Secrets

| Variable | Default | Notes |
|----------|---------|-------|
| `MARIADB_IMAGE` | `mariadb:lts` | MariaDB image tag. |
| `MARIADB_PASSWORD_PATH` | `./secrets/` | Directory holding the user password file. |
| `MARIADB_PASSWORD_FILENAME` | `MARIADB_PASSWORD` | Secret file for the application user. |
| `MARIADB_ROOT_PASSWORD_PATH` | `./secrets/` | Directory holding the root password file. |
| `MARIADB_ROOT_PASSWORD_FILENAME` | `MARIADB_ROOT_PASSWORD` | Secret file for the root account. |

### Performance Tuning

| Variable | Default | Notes |
|----------|---------|-------|
| `MARIADB_INNODB_BUFFER_POOL_SIZE` | `2G` | Buffer pool size (recommended ~70% of container RAM limit). |
| `MARIADB_INNODB_LOG_FILE_SIZE` | `256M` | InnoDB redo log size. |
| `MARIADB_INNODB_IO_CAPACITY` | `1000` | IOPS hint (increase for SSD/NVMe). |
| `MARIADB_SORT_BUFFER_SIZE` | `2M` | Session sort buffer for ORDER BY/GROUP BY. |
| `MARIADB_MAX_ALLOWED_PACKET` | `64M` | Maximum packet size for client/server communication. |

Edit `templates/mariadb/.env` to suit your workload before launching dependent apps.

---

## Server Flags

The following flags are set via `command:` in the compose file:

- `--innodb_use_native_aio=0` — Disable native AIO (required in Proxmox LXC)
- `--character-set-server=utf8mb4` + `--collation-server=utf8mb4_unicode_ci`
- `--transaction-isolation=READ-COMMITTED` + `--binlog-format=ROW`
- `--log-bin=binlog` — Binary logging for replication/point-in-time recovery
- `--innodb_flush_log_at_trx_commit=2` — Balances durability and performance

---

## Volumes & Secrets

- Named volume `database` -> `/var/lib/mysql` stores the data directory.
- Timezone files mounted read-only.
- Secrets required:
  - `MARIADB_PASSWORD` -> `/run/secrets/MARIADB_PASSWORD`
  - `MARIADB_ROOT_PASSWORD` -> `/run/secrets/MARIADB_ROOT_PASSWORD`

### Environment

| Variable | Value | Notes |
|----------|-------|-------|
| `MARIADB_USER` | `${APP_NAME}` | Application database user. |
| `MARIADB_DATABASE` | `${APP_NAME}` | Default database name. |
| `MARIADB_AUTO_UPGRADE` | `true` | Auto-upgrade data directory on version changes. |
| `MARIADB_PASSWORD_FILE` | `/run/secrets/MARIADB_PASSWORD` | Secret injection via `_FILE` suffix. |
| `MARIADB_ROOT_PASSWORD_FILE` | `/run/secrets/MARIADB_ROOT_PASSWORD` | Root secret injection. |

---

## Security

- `user: 999:999` (non-root)
- `read_only: true`
- `cap_drop: ALL` with minimal `cap_add`: `SETUID`, `SETGID`, `CHOWN`
- `no-new-privileges:true` + AppArmor confinement
- `init: true`, `stop_grace_period: 30s`, `oom_score_adj: -500`
- `tmpfs`: `/run`, `/tmp`, `/run/mysqld`

---

## Networking

Connected to `backend` network only. No Traefik labels (not publicly exposed).

---

## Healthcheck

```yaml
test: ['CMD', 'healthcheck.sh', '--connect', '--innodb_initialized']
interval: 30s
timeout: 5s
retries: 3
start_period: 10s
```

---

## Maintenance Hints

- No dependencies — MariaDB starts independently and other services depend on it.
- Pair with `templates/mariadb_maintenance` for automated backup/restore.
- The container runs fully read-only; any migrations requiring extra directories must be mounted explicitly.
- Make sure the consuming stack sets `APP_NAME` so container/database names are namespaced properly.
