# Hardened Application Compose Template

This template delivers a security-first baseline for running an application service with Docker Compose. It assumes your workload is reverse-proxied (e.g., by Traefik), relies on Docker secrets for sensitive data, and should run happily on any modern Linux host.

## Quick Start

1. Copy `.env` and `docker-compose.app.yaml` into your project and adjust the values marked with `set-me` or descriptive comments.
2. Create the external networks referenced by default (`frontend` and `backend`) or rename them to match your environment.
3. Place sensitive material in the path defined by `APP_PASSWORD_PATH` and ensure the file name matches `APP_PASSWORD_FILENAME`.
4. Verify ownership of bind-mounted host paths so that the `APP_UID` and `APP_GID` in `.env` have the expected access.
5. Run `docker compose --env-file .env -f docker-compose.app.yaml config` to confirm variable interpolation succeeds before starting the stack.

## Environment Variables

| Variable | Purpose |
| --- | --- |
| `IMAGE`, `APP_NAME` | Describe the image to pull and the canonical container name. |
| `APP_UID`, `APP_GID` | Enforce a non-root runtime user; align with file ownership on mounted volumes. |
| `TRAEFIK_HOST`, `TRAEFIK_PORT` | Feed routing rules and upstream port information to Traefik labels. |
| `APP_PASSWORD_PATH`, `APP_PASSWORD_FILENAME`, `APP_PASSWORD_FILE` | Control how Docker secrets are sourced from the host and referenced inside the container. |
| `SECCOMP_PROFILE`, `APPARMOR_PROFILE` | Harden the container with syscall and mandatory access control profiles (override when debugging or on unsupported hosts). |
| `MEM_LIMIT`, `CPU_LIMIT`, `PIDS_LIMIT` | Keep resource consumption predictable and defend against runaway workloads. |
| `SHM_SIZE` | Control the `/dev/shm` tmpfs size for workloads that need larger shared memory segments. |
| `ENV_VAR_EXAMPLE` | Placeholder for application-specific configuration; extend this section with your real environment variables. |

Tighten or loosen defaults only after you understand the security trade-offs. Leaving unnecessary privileges or broad resource limits defeats the purpose of the template.

## Security and Hardening Highlights

- **Non-root execution** via `user: "${APP_UID}:${APP_GID}"`.
- **Read-only root filesystem** combined with controlled volume mounts. The bundled `data` volume is read-only until you explicitly opt into write access.
- **Dropped Linux capabilities** and **no-new-privileges** to prevent escalation.
- **Mandatory seccomp and AppArmor profiles** with overridable defaults.
- **Tmpfs mounts** for runtime directories (`/run`, `/tmp`, `/var/tmp`) to avoid persisting transient files to disk.
- **Docker secrets** required by default, guaranteeing credentials never leak into plain environment variables.
- **Resource ceilings** for memory, CPU, PID counts, and shared memory to mitigate runaway processes or fork bombs.

## Optional Adjustments

- Add `cap_add` entries only when the application breaks without a capability.
- Replace the `curl`-based health check if your image bundles a different tool or provide your own health endpoint.
- Switch the `data` volume to `:rw` only after you audit and understand every file the application writes.
- If your host does not support AppArmor, set `APPARMOR_PROFILE=unconfined` and document why; do the same for seccomp when necessary.
- Wire in additional secrets by declaring them under both the service `secrets:` block and the top-level `secrets:` section.

## Verification

After editing the template:

```bash
docker compose --env-file .env -f docker-compose.app.yaml config
docker compose --env-file .env -f docker-compose.app.yaml up -d
```

Monitor with `docker compose ps` and `docker compose logs --tail 100 -f app` to confirm the container remains healthy under the imposed restrictions. If you relax any defaults, document the rationale so future maintainers can re-evaluate the implications.
