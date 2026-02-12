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
| `CLAMD_STARTUP_TIMEOUT` | `1800` | Max seconds to wait for clamd database loading |
| `FRESHCLAM_CHECKS` | `1` | Number of virus database update checks per day |

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

## Notes

- First startup takes several minutes while ClamAV loads virus signature databases
- The `freshclam` daemon runs inside the container and automatically updates virus signatures
- Memory usage is ~1-2 GB due to the virus signature database loaded into RAM
- `read_only` filesystem is not enabled because `freshclam` creates temporary files during database updates
