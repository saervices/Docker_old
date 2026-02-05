# Hytale Dedicated Server

Compose bundle for the Hytale dedicated server image (`indifferentbroccoli/hytale-server-docker`). Ships with persistent server storage, automatic updates, and built-in backup support.

---

## Components
- **app** -- Dedicated server container exposing UDP `5520` (QUIC protocol).
- No database dependencies; runs standalone on the `frontend` network.
- Health check via Java process detection (`pgrep -f HytaleServer.jar`), with a 120s start period for initial download and AOT cache build.

---

## Configuration

| Variable | Default | Notes |
|----------|---------|-------|
| `IMAGE` | `indifferentbroccoli/hytale-server-docker` | Dedicated server image. |
| `APP_NAME` | `hytale` | Used for container name and hostname. |
| `PUID` | `1000` | User ID for file ownership inside the container. |
| `PGID` | `1000` | Group ID for file ownership inside the container. |
| `SERVER_NAME` | `hytale` | Server name shown to players. |
| `DEFAULT_PORT` | `5520` | UDP port for game traffic (QUIC protocol). |
| `MAX_PLAYERS` | `20` | Maximum concurrent players. |
| `VIEW_DISTANCE` | `12` | Chunk view distance (primary RAM driver). |
| `AUTH_MODE` | `authenticated` | `authenticated` or `offline`. |
| `MAX_MEMORY` | `8G` | JVM maximum heap size. |
| `ENABLE_BACKUPS` | `false` | Enable automatic world backups. |
| `BACKUP_FREQUENCY` | `30` | Backup interval in minutes (if enabled). |
| `DISABLE_SENTRY` | `true` | Disable crash reporting telemetry. |
| `USE_AOT_CACHE` | `true` | Ahead-of-Time compilation cache for faster startup. |
| `DOWNLOAD_ON_START` | `true` | Auto-download/update server files on start. |

Update `Gameserver/Hytale/.env` to change the image tag or adjust server settings.

---

## Volumes & Ports
- Named volume `data` -> `/home/hytale/server-files` persists world saves, configuration, mods, and backups.
- Timezone files mounted read-only for accurate timestamps.
- Port exposed:
  - `5520/udp` -- game traffic (QUIC protocol; **UDP only**, no TCP)

---

## Usage
1. Adjust `.env` values, especially `MAX_PLAYERS`, `VIEW_DISTANCE`, and `MAX_MEMORY`.
2. Start the server: `docker compose -f docker-compose.app.yaml up -d`.
3. **First start only:** Check logs with `docker compose -f docker-compose.app.yaml logs -f app`. The server will display an OAuth URL -- visit it in your browser and log in with your Hytale account to authorize the server. Credentials are persisted for subsequent starts.
4. Ensure your firewall allows **UDP** traffic on port `5520`.

---

## Maintenance Hints
- View distance exponentially impacts RAM usage. Keep it at 12 or below for stable performance.
- Container runs with additional capabilities (`CHOWN`, `FOWNER`, `DAC_OVERRIDE`, `KILL`) required by the upstream image to manage server files and send shutdown signals to the Java process.
- Set `ENABLE_BACKUPS=true` and adjust `BACKUP_FREQUENCY` for automatic world backups.
- Back up the `data` volume regularly; all saves, config, and mods reside there.
- Set `AUTH_MODE=offline` for LAN-only servers that do not require Hytale account authentication.
