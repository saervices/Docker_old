# ClamAV Template

ClamAV antivirus daemon (`clamd`) for on-demand file scanning via TCP. Designed for integration with applications like Seafile that support `clamdscan` as a scan command.

## Requirements

- **Seafile Professional Edition** (`seafileltd/seafile-pro-mc`) required for virus scanning (free for up to 3 users)
- Docker network `backend` must exist: `docker network create backend`
- Sufficient RAM (~1-2 GB for virus signature database)

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAMAV_IMAGE` | `clamav/clamav:latest` | Container image |
| `CLAMAV_STARTUP_TIMEOUT` | `1800` | Max seconds to wait for clamd database loading |
| `CLAMAV_FRESHCLAM_CHECKS` | `1` | Number of virus database update checks per day |

### Scan Settings (set in app .env, used by `inject_extra_settings.sh`)

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAMAV_SCAN_INTERVAL` | `5` | Minutes between background virus scan runs |
| `CLAMAV_SCAN_SIZE_LIMIT` | `20` | Max file size to scan in MB (`0` = unlimited) |
| `CLAMAV_SCAN_THREADS` | `2` | Number of concurrent scanning threads |

## Volumes

| Volume | Path | Description |
|--------|------|-------------|
| `clamav_database` | `/var/lib/clamav` | Virus signature database (persisted) |

## Usage

```yaml
x-required-services:
  - clamav
```

## Connection

ClamAV daemon (`clamd`) listens on **TCP port 3310** within the `backend` Docker network. Other containers on the same network can connect using the service name `clamav` as hostname.

### Client Configuration

To connect `clamdscan` from another container, create a `clamd.conf` with:

```
TCPSocket 3310
TCPAddr clamav
```

Mount this file at `/etc/clamav/clamd.conf` in the client container.

## Security

- `cap_drop: ALL` with minimal `cap_add`: `SETUID`, `SETGID`, `CHOWN`, `DAC_OVERRIDE`, `FOWNER`
- `FOWNER` is required for `freshclam` to bypass permission checks during virus database updates
- `TINI_SUBREAPER: "1"` enables tini sub-reaper mode for proper zombie process cleanup (ClamAV runs multiple daemons: `clamd` + `freshclam`)
- `read_only` filesystem is not enabled because `freshclam` creates temporary files during database updates

## Notes

- First startup takes several minutes while ClamAV loads virus signature databases
- The `freshclam` daemon runs inside the container and automatically updates virus signatures
- Memory usage is ~1-2 GB due to the virus signature database loaded into RAM
