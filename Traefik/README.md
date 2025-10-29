# Traefik Reverse Proxy

Reverse proxy and certificate manager fronting the rest of the stack. The compose file wires Traefik to Cloudflare DNS-01 challenges, Traefik dashboards, static/dynamic configuration files, and the socket-proxy for Docker discovery.

---

## Components
- **traefik** – single container exposing ports 80/443 with dynamic configuration sourced from `appdata/config`.
- Depends on the Docker API (via socket-proxy) and Authentik for the forward-auth middleware configured in the labels.

---

## Configuration

| Variable | Default | Notes |
|----------|---------|-------|
| `IMAGE` | `traefik` | Traefik image tag. |
| `APP_NAME` | `traefik` | Used for container name and Traefik labels. |
| `TRAEFIK_HOST` | `Host(\`traefik.example.com\`)` | Dashboard/router host rule. |
| `TRAEFIK_DOMAIN` | `example.com` | Base domain used by static TLS options. |
| `TRAEFIK_PORT` | `8080` | Dashboard port exposed internally (proxied by Traefik itself). |
| `CF_DNS_API_TOKEN_PATH` | `./secrets/` | Folder with the Cloudflare API token. |
| `CF_DNS_API_TOKEN_FILENAME` | `CF_DNS_API_TOKEN` | Secret file name for DNS-01 validation. |
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
| `SOCKETPROXY_CONTAINERS` | `1` | Grants Traefik read access to the Docker API via socket-proxy. |

Populate or adjust these values in `Traefik/.env`.

---

## Volumes & Secrets
- `./appdata/config/middlewares.yaml` → `/etc/traefik/conf.d/middlewares.yaml`
- `./appdata/config/tls-opts.yaml` → `/etc/traefik/conf.d/tls-opts.yaml`
- `./appdata/config/conf.d/` → `/etc/traefik/conf.d/rules/` for dynamic routers/services.
- `./appdata/config/certs/` → `/var/traefik/certs` for ACME storage and imported certificates.
- `/var/log/traefik` mapped from the host to persist access/error logs (create it with proper permissions).
- Secret `CF_DNS_API_TOKEN` stored in `secrets/CF_DNS_API_TOKEN` and mounted at runtime.

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
- Logs rotate via the Docker log driver (10 MB ×3) in addition to the mapped `/var/log/traefik` path—monitor disk usage there.
