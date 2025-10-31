# Docker Socket Proxy Template

Least-privilege Compose fragment wrapping `lscr.io/linuxserver/socket-proxy`. Combine it with Traefik or other stacks that need Docker discovery without exposing a raw Docker socket.

---

## Highlights
- Container name and hostname resolve to `${APP_NAME}-${SOCKETPROXY_APP_NAME}`, keeping every stack’s helper instance distinct.
- Docker socket stays read-only; everything else is read-only or tmpfs-backed to reduce persistence and tampering.
- Capabilities are dropped, `no-new-privileges` and AppArmor are enforced, and the health check watches for socket regressions.

---

## How To Use It
1. In the parent stack `.env`, provide `APP_NAME` (e.g., `APP_NAME=traefik`). In this template’s `.env`, adjust `SOCKETPROXY_APP_NAME` if you want a suffix other than `socketproxy`.
2. Ensure the container runs with permissions to read `/var/run/docker.sock`. The simplest route is to run as root (commented `user:` line). If you need a non-root UID/GID, grant it membership in the host’s Docker group (`stat -c '%g' /var/run/docker.sock`) or adjust ACLs accordingly.
3. Ensure the external network referenced here (`backend` by default) already exists or rename it in both the compose file and `.env`.
4. Leave all Docker API flags at `0`, enable (`1`) only the endpoints the consuming service needs, then bring both compose files up together:
   ```bash
   docker compose --env-file Traefik/.env \
     -f Traefik/docker-compose.app.yaml \
     -f templates/socketproxy/docker-compose.socketproxy.yaml up -d
   ```

---

## Environment Variables

**Container identity & runtime**

| Variable | Default | Description |
| --- | --- | --- |
| `SOCKETPROXY_IMAGE` | `lscr.io/linuxserver/socket-proxy` | Upstream image reference pulled for the proxy. |
| `SOCKETPROXY_APP_NAME` | `socketproxy` | Suffix appended to `${APP_NAME}-` for the container name, hostname, and labels. |
| `SOCKETPROXY_APP_UID` | `1000` | UID applied when the optional `user:` stanza is enabled; match bind-mount ownership. |
| `SOCKETPROXY_APP_GID` | `1000` | GID counterpart to the UID above. |
| `SOCKETPROXY_APPARMOR_PROFILE` | `docker-default` | AppArmor profile enforced on the container; set to `unconfined` if unsupported. |
| `SOCKETPROXY_LOG_LEVEL` | `err` | Nginx log verbosity (`debug`, `info`, `notice`, `warning`, `err`, `crit`, `alert`, `emerg`). |
| `SOCKETPROXY_DISABLE_IPV6` | `1` | Toggles IPv6 inside the container (`1` disables it). |

**Resource governance**

| Variable | Default | Description |
| --- | --- | --- |
| `SOCKETPROXY_MEM_LIMIT` | `512m` | Memory ceiling applied via Compose (`mem_limit`). |
| `SOCKETPROXY_CPU_LIMIT` | `1.0` | CPU quota (`1.0` equals one full core). |
| `SOCKETPROXY_PIDS_LIMIT` | `128` | Bounds the number of processes/threads to contain runaway workloads. |
| `SOCKETPROXY_SHM_SIZE` | `64m` | Size of `/dev/shm` inside the container. |

**Docker API permissions**  
Set to `1` to allow the endpoint, `0` to reject it.

| Variable | Default | Endpoint scope |
| --- | --- | --- |
| `SOCKETPROXY_AUTH` | `0` | `/auth` (registry authentication). |
| `SOCKETPROXY_BUILD` | `0` | `/build` (image builds). |
| `SOCKETPROXY_COMMIT` | `0` | `/commit` (commit container state to image). |
| `SOCKETPROXY_CONFIGS` | `0` | `/configs` (Swarm configs). |
| `SOCKETPROXY_CONTAINERS` | `0` | `/containers` (start/stop/manage containers). |
| `SOCKETPROXY_DISTRIBUTION` | `0` | `/distribution` (registry distribution metadata). |
| `SOCKETPROXY_EVENTS` | `1` | `/events` (stream Docker events). |
| `SOCKETPROXY_EXEC` | `0` | `/exec` (attach/exec inside containers). |
| `SOCKETPROXY_IMAGES` | `0` | `/images` (inspect, pull, remove images). |
| `SOCKETPROXY_INFO` | `0` | `/info` (engine state). |
| `SOCKETPROXY_NETWORKS` | `0` | `/networks` (create/inspect networks). |
| `SOCKETPROXY_NODES` | `0` | `/nodes` (Swarm nodes). |
| `SOCKETPROXY_PING` | `1` | `/_ping` health endpoint. |
| `SOCKETPROXY_PLUGINS` | `0` | `/plugins` management. |
| `SOCKETPROXY_SECRETS` | `0` | `/secrets` (Swarm secrets). |
| `SOCKETPROXY_SERVICES` | `0` | `/services` (Swarm services). |
| `SOCKETPROXY_SESSION` | `0` | `/session` (interactive sessions). |
| `SOCKETPROXY_SWARM` | `0` | `/swarm` (Swarm cluster config). |
| `SOCKETPROXY_SYSTEM` | `0` | `/system` (system prune and info). |
| `SOCKETPROXY_TASKS` | `0` | `/tasks` (Swarm tasks). |
| `SOCKETPROXY_VERSION` | `1` | `/version` (engine version details). |
| `SOCKETPROXY_POST` | `0` | Global toggle for write verbs (POST/PUT/DELETE). |
| `SOCKETPROXY_VOLUMES` | `0` | `/volumes` (create/remove volumes). |

**Write overrides**  
Only effective when `SOCKETPROXY_POST` stays `0`.

| Variable | Default | Description |
| --- | --- | --- |
| `SOCKETPROXY_ALLOW_START` | `0` | Permit container start operations. |
| `SOCKETPROXY_ALLOW_STOP` | `0` | Permit container stop operations. |
| `SOCKETPROXY_ALLOW_RESTARTS` | `0` | Permit container restarts. |

---

## Security Defaults
- Read-only root filesystem plus narrow bind mounts keep the proxy immutable at runtime.
- `cap_drop: ["ALL"]` combined with `no-new-privileges` blocks capability escalation.
- Tmpfs for `/run`, `/tmp`, and `/var/tmp` keeps transient files in memory only.
- Health check (`stat /var/run/docker.sock`) detects permission or mount issues quickly.

---

## Maintenance Tips
- Start with every API flag disabled; enable new endpoints only after validating the exact call required.
- Inspect proxy logs if a client hits permission errors—denied requests show up at the configured log level.
- When multiple stacks share this proxy, reinforce isolation with Docker networks or host-level firewall rules in addition to the in-proxy ACLs.
