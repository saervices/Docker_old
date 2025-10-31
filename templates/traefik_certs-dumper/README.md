# Traefik Certs Dumper Template

Helper container that tails Traefik’s ACME store and mirrors certificates to remote hosts through `scp`. Use it alongside the Traefik stack when you need off-box copies of certificates for appliances such as Mailcow, TrueNAS, or OPNsense.

---

## Highlights
- Builds on `ldez/traefik-certs-dumper`, adding `openssh-client` and `jq` so the entrypoint can watch `cloudflare-acme.json` and execute secure copy hooks.
- Runs with a read-only root filesystem, dropped capabilities, tmpfs-backed SSH directory, and health checks that ensure the ACME store is reachable.
- The bundled `post-hook.sh` script copies a certificate/key pair to a Mailcow host and restarts its Compose stack; extend it with additional targets as needed.

---

## Integration Steps
1. Provide `APP_NAME` in your main Traefik `.env` (e.g., `APP_NAME=traefik`). In this template’s `.env`, adjust `TRAEFIK_CERTS_DUMPER_APP_NAME` if you want a suffix other than `certs-dumper`.
2. Mount the same certificate directory Traefik uses (`./appdata/config/certs` by default) so the dumper sees `cloudflare-acme.json`.
3. Place the SSH private key at `secrets/id_rsa` (or update the volume) and ensure the remote hosts accept key authentication. The script creates `/root/.ssh/known_hosts` on the tmpfs volume and accepts new keys automatically.
4. Run the container with access to `/root/.ssh` and the mounted key. Default (root) execution works out of the box. If you must drop privileges, relocate the key and known_hosts file into a path owned by your chosen UID/GID and adjust the compose file plus hook script accordingly.
5. Start both stacks together:
   ```bash
   docker compose --env-file Traefik/.env \
     -f Traefik/docker-compose.app.yaml \
     -f templates/socketproxy/docker-compose.socketproxy.yaml \
     -f templates/traefik_certs-dumper/docker-compose.traefik_certs-dumper.yaml up -d
   ```
6. Tail logs with `docker compose logs -f traefik_certs-dumper` to confirm hooks run when Traefik renews certificates.

---

## Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `TRAEFIK_CERTS_DUMPER_APP_NAME` | `certs-dumper` | Suffix appended to `${APP_NAME}-` for the container name and hostname. |
| `TRAEFIK_CERTS_DUMPER_APP_UID` | `1000` | UID applied when you enable the optional `user:` setting (match bind-mount ownership). |
| `TRAEFIK_CERTS_DUMPER_APP_GID` | `1000` | GID counterpart to the UID above. |
| `TRAEFIK_CERTS_DUMPER_APPARMOR_PROFILE` | `docker-default` | AppArmor profile enforced on compatible hosts; set to `unconfined` only when unsupported. |
| `TRAEFIK_CERTS_DUMPER_MEM_LIMIT` | `512m` | Compose memory ceiling for the container. |
| `TRAEFIK_CERTS_DUMPER_CPU_LIMIT` | `1.0` | CPU quota (`1.0` equals one full core). |
| `TRAEFIK_CERTS_DUMPER_PIDS_LIMIT` | `128` | Limits concurrent processes/threads inside the container. |
| `TRAEFIK_CERTS_DUMPER_SHM_SIZE` | `64m` | Size of `/dev/shm`; bump if hooks need more shared memory. |

The compose file references `${APP_NAME}` from the parent Traefik environment. Uncomment `TRAEFIK_CERTS_DUMPER_IMAGE` if you prefer pulling a pre-built image instead of building locally.

---

## Anatomy Of The Build & Runtime

**Dockerfile – `dockerfiles/dockerfile.traefik-certs-dumper.scp`**  
Extends `ldez/traefik-certs-dumper` and installs `openssh-client` (for `scp`/`ssh`) and `jq` (used by the entrypoint wait loop). Rebuild the image whenever you change the Dockerfile or the hook script:
```bash
docker compose build traefik_certs-dumper
```

**Entrypoint (defined in the compose file)**  
Overrides the default entrypoint to:
- Wait until `/data/cloudflare-acme.json` exists and contains at least one certificate (using `jq` for the count).
- Launch `traefik-certs-dumper` with `--watch` and `--post-hook` so every renewal triggers `/config/post-hook.sh`.

**Post-hook script – `scripts/post-hook.sh`**  
Written in Bash with `set -euo pipefail`:
- `install_openssh` ensures `scp` exists (should be a no-op after the Dockerfile install) and initialises `/root/.ssh/known_hosts` on the tmpfs mount.
- `copy_certificates` and `restart_remote_docker_compose` wrap `scp`/`ssh` with strict host key handling and a shared private key.
- `mailcow` copies the renewed certificate/key to `/opt/mailcow-dockerized` on a remote host, then restarts that stack.
- `example_other_service` is a template function—clone it for each additional destination you need.
- The `main` section currently calls `mailcow`; add or remove function calls to match your environment.

---

## Compose Considerations
- **Volumes**:  
  `./scripts/post-hook.sh` mounts read-only at `/config/post-hook.sh`; adjust if you split scripts per destination.  
  The certificate store binds to `/data` — align this with Traefik’s `acme.json` location.  
  The SSH private key binds to `/root/.ssh/id_rsa` (read-only); supply your own key file and secure permissions on the host.
- **Networks**:  
  Joins the `backend` network by default so it shares the same scope as Traefik. Rename if your environment uses different network names.
- **depends_on**:  
  Default dependency is `app` (the service name in the Traefik compose file). Update this if your Traefik service uses a different identifier.
- **Healthcheck**:  
  Simple `test -f /data/cloudflare-acme.json`. Extend it if you want deeper validation (e.g., ensure the JSON parses or checks expiration dates).

---

## Customisation Tips
- Duplicate the `mailcow` function or convert the script to read a destinations file/environment variables if you manage many endpoints. Keep the `ssh_opts` array so host key handling stays consistent.
- If remote paths contain spaces, wrap them in environment variables and escape them appropriately inside the SSH command.
- Harden remote restarts by running more specific commands (e.g., `docker compose up -d service` or system-specific reload scripts) instead of `restart`.
- Keep the SSH key on the host with tight permissions (`chmod 600`). Because `/root/.ssh` lives on tmpfs, known hosts are discarded on container restarts—plan to accept keys again or pre-load them via another mount.
- For alternative ACME filenames, change the wait loop and `--source` flag accordingly.
