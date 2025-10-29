# Traefik Reverse Proxy

Reverse proxy and certificate manager fronting the rest of the stack. The compose file wires Traefik to Cloudflare DNS-01 challenges, Traefik dashboards, static/dynamic configuration files, and the socket-proxy for Docker discovery.

---

## Components
- **traefik** – single container exposing ports 80/443 with dynamic configuration sourced from `appdata/config`.
- **socketproxy** – required helper pulled in via `x-required-services` (see `templates/socketproxy`) to expose the Docker API securely.
- **traefik_certs-dumper** – optional helper referenced through `x-required-services` (see `templates/traefik_certs-dumper`) that mirrors certificates via SSH hooks.

---

## Configuration

| Variable | Default | Notes |
|----------|---------|-------|
| `IMAGE` | `traefik` | Traefik image tag. |
| `APP_NAME` | `traefik` | Used for container name and Traefik labels. |
| `APP_UID` / `APP_GID` | `1000` | Drop Traefik to a non-root user inside the container. |
| `SECCOMP_PROFILE` / `APPARMOR_PROFILE` | `/etc/docker/seccomp.json` / `docker-default` | Security profiles enforced on the container (set to `unconfined` only while debugging). |
| `TRAEFIK_HOST` | `Host(\`traefik.example.com\`)` | Dashboard/router host rule (string must be escaped in `.env`). |
| `TRAEFIK_DOMAIN` | `example.com` | Base domain used by static TLS options. |
| `TRAEFIK_PORT` | `8080` | Dashboard port exposed internally (proxied by Traefik itself). |
| `CF_DNS_API_TOKEN_PATH` | `./secrets/` | Folder containing the Cloudflare API token. |
| `CF_DNS_API_TOKEN_FILENAME` | `CF_DNS_API_TOKEN` | File name holding the Cloudflare token. |
| `LOG_LEVEL` | `ERROR` | Traefik log level (`DEBUG`, `INFO`, `WARN`, etc.). |
| `LOG_FORMAT` | `common` | Log format for both access and error logs. |
| `BUFFERINGSIZE` | `10` | Access log buffering (lines). |
| `LOG_STATUSCODES` | `400-499,500-599` | Filter which requests end up in the access log. |
| `LOCAL_IPS` | `127.0.0.1/32,...` | CIDR list for trusted origins (used by middleware files). |
| `CLOUDFLARE_IPS` | long list | Cloudflare edge networks for IP whitelisting. |
| `TRAEFIK_DOMAIN_1/2` | *(commented)* | Optional additional domains handled by TLS files. |
| `MIDDLEWARES` | `global-security-headers@file,global-rate-limit@file` | Default middlewares applied to routers. |
| `TLSOPTIONS` | `global-tls-opts@file` | TLS option set for routers. |
| `EMAIL_PREFIX` | `admin` | Local part for Let's Encrypt notification email. |
| `KEYTYPE` | `EC256` | Private key type for ACME certificates. |
| `CERTRESOLVER` | `cloudflare` | ACME resolver name used in router labels. |
| `DNSCHALLENGE_RESOLVERS` | `1.1.1.1:53,1.0.0.1:53` | DNS servers used for ACME propagation checks. |
| `AUTHENTIK_CONTAINER_NAME` | `authentik` | Used by the authentik-proxy middleware reference. |
| `MEM_LIMIT` / `CPU_LIMIT` / `PIDS_LIMIT` / `SHM_SIZE` | `512m` / `1.0` / `128` / `64m` | Resource ceilings applied to the container. |
| `SOCKETPROXY_CONTAINERS` | `1` | Grants Traefik read access to the Docker API via socket-proxy. |

Populate or adjust these values in `Traefik/.env`.

---

## Volumes & Secrets
- `./appdata/config/middlewares.yaml` → `/etc/traefik/conf.d/middlewares.yaml`
- `./appdata/config/tls-opts.yaml` → `/etc/traefik/conf.d/tls-opts.yaml`
- `./appdata/config/conf.d/` → `/etc/traefik/conf.d/rules/` for dynamic routers/services.
- `./appdata/config/certs/` → `/var/traefik/certs` for ACME storage and imported certificates.
- Secret `CF_DNS_API_TOKEN` stored in `secrets/CF_DNS_API_TOKEN` and mounted at runtime.
- Traefik logs stay inside the container on a tmpfs mount (`/var/log/traefik`); rely on the Docker log driver rotation (`10 MB ×3`) for persistence.

---

## Usage
1. Fill in `Traefik/.env` (domain names, Cloudflare token path, logging preferences).
2. Place the Cloudflare API token in `Traefik/secrets/CF_DNS_API_TOKEN` (plain text).
3. Prepare configuration files under `appdata/config/` and ensure `conf.d` contains your router rules.
4. Start Traefik: `docker compose -f docker-compose.app.yaml up -d`.

---

## Maintenance Hints
- The dashboard is enabled (`--api.insecure=true`); keep the router behind Authentik or restrict by IP using the shipped middlewares.
- When you add new subdomains, drop rule files in `appdata/config/conf.d` and Traefik will reload automatically.
- ACME certificates land in `appdata/config/certs/acme.json`; back it up and keep permissions tight (600).
- Logs rotate via the Docker log driver (10 MB ×3); take external copies if you need persistent log history because `/var/log/traefik` is tmpfs-backed.
