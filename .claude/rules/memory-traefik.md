# Memory: Traefik Integration Standards

Guidelines for integrating services with the Traefik reverse proxy.

---

## Required Labels

Every service exposed via Traefik needs these labels:

```yaml
labels:
  # Enable Traefik for this container
  - "traefik.enable=true"

  # Router configuration
  - "traefik.http.routers.${APP_NAME}-rtr.rule=${TRAEFIK_HOST}"
  - "traefik.http.routers.${APP_NAME}-rtr.entrypoints=websecure"
  - "traefik.http.routers.${APP_NAME}-rtr.tls.certresolver=letsencrypt"

  # Service configuration (internal port)
  - "traefik.http.services.${APP_NAME}-svc.loadBalancer.server.port=${TRAEFIK_PORT:?Port required}"
```

## Environment Variables for Traefik

```bash
# In .env file
TRAEFIK_HOST=Host(`myapp.example.com`)
TRAEFIK_PORT=8080
```

### Multiple Hostnames

```bash
# OR syntax for multiple domains
TRAEFIK_HOST=Host(`app.domain1.com`) || Host(`app.domain2.com`)

# Subdomain wildcard
TRAEFIK_HOST=HostRegexp(`{subdomain:[a-z]+}.domain.com`)
```

---

## Available Middlewares

Located in `Traefik/appdata/config/middlewares.yaml`:

| Middleware | Reference | Usage |
|------------|-----------|-------|
| Authentik Forward Auth | `authentik-proxy@file` | SSO authentication |
| WebSocket Headers | `websocket-security-headers@file` | Collabora, OnlyOffice, live editing |
| Local Network Only | `local-IPAllowList@file` | Restrict to private IPs |
| Rate Limiting | `global-rate-limit@file` | 50 req/s average, 100 burst |
| Security Headers | `global-security-headers@file` | HSTS, XSS protection, etc. |

### Applying Middlewares

```yaml
labels:
  # Single middleware
  - "traefik.http.routers.${APP_NAME}-rtr.middlewares=authentik-proxy@file"

  # Multiple middlewares (comma-separated)
  - "traefik.http.routers.${APP_NAME}-rtr.middlewares=authentik-proxy@file,global-rate-limit@file"
```

---

## Network Assignment

### Rules

| Service Type | Networks | Reason |
|--------------|----------|--------|
| Web apps (Traefik-exposed) | `frontend` + `backend` | Needs Traefik access + internal services |
| Databases | `backend` only | Never expose to reverse proxy |
| Cache (Redis) | `backend` only | Internal access only |
| Background workers | `backend` only | No web access needed |

### Configuration

```yaml
networks:
  - frontend    # For Traefik access
  - backend     # For internal communication

# At bottom of compose file
networks:
  frontend:
    external: true
  backend:
    external: true
```

### Create Networks (One-Time Setup)

```bash
docker network create frontend
docker network create backend
```

---

## Common Patterns

### Standard Web Application

```yaml
services:
  app:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${APP_NAME}-rtr.rule=${TRAEFIK_HOST}"
      - "traefik.http.routers.${APP_NAME}-rtr.entrypoints=websecure"
      - "traefik.http.routers.${APP_NAME}-rtr.tls.certresolver=letsencrypt"
      - "traefik.http.services.${APP_NAME}-svc.loadBalancer.server.port=${TRAEFIK_PORT}"
    networks:
      - frontend
      - backend
```

### With Authentik SSO

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.${APP_NAME}-rtr.rule=${TRAEFIK_HOST}"
  - "traefik.http.routers.${APP_NAME}-rtr.entrypoints=websecure"
  - "traefik.http.routers.${APP_NAME}-rtr.tls.certresolver=letsencrypt"
  - "traefik.http.routers.${APP_NAME}-rtr.middlewares=authentik-proxy@file"
  - "traefik.http.services.${APP_NAME}-svc.loadBalancer.server.port=${TRAEFIK_PORT}"
```

### WebSocket Support (Collabora, OnlyOffice)

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.${APP_NAME}-rtr.rule=${TRAEFIK_HOST}"
  - "traefik.http.routers.${APP_NAME}-rtr.entrypoints=websecure"
  - "traefik.http.routers.${APP_NAME}-rtr.tls.certresolver=letsencrypt"
  - "traefik.http.routers.${APP_NAME}-rtr.middlewares=websocket-security-headers@file"
  - "traefik.http.services.${APP_NAME}-svc.loadBalancer.server.port=${TRAEFIK_PORT}"
```

### Local Network Only (Admin Panels)

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.${APP_NAME}-rtr.rule=${TRAEFIK_HOST}"
  - "traefik.http.routers.${APP_NAME}-rtr.entrypoints=websecure"
  - "traefik.http.routers.${APP_NAME}-rtr.tls.certresolver=letsencrypt"
  - "traefik.http.routers.${APP_NAME}-rtr.middlewares=local-IPAllowList@file"
  - "traefik.http.services.${APP_NAME}-svc.loadBalancer.server.port=${TRAEFIK_PORT}"
```

### Multiple Routers (API + Web)

```yaml
labels:
  # Web interface
  - "traefik.http.routers.${APP_NAME}-web-rtr.rule=Host(`app.example.com`)"
  - "traefik.http.routers.${APP_NAME}-web-rtr.service=${APP_NAME}-web-svc"
  - "traefik.http.services.${APP_NAME}-web-svc.loadBalancer.server.port=80"

  # API endpoint
  - "traefik.http.routers.${APP_NAME}-api-rtr.rule=Host(`api.example.com`)"
  - "traefik.http.routers.${APP_NAME}-api-rtr.service=${APP_NAME}-api-svc"
  - "traefik.http.services.${APP_NAME}-api-svc.loadBalancer.server.port=8080"
```

---

## Internal Services (No Traefik)

For services that should NOT be exposed:

```yaml
services:
  postgresql:
    # No labels section - not exposed
    networks:
      - backend    # Only backend, no frontend
```

---

## Traefik Dependencies

The Traefik stack requires:

```yaml
x-required-services:
  - socketproxy           # Secure Docker socket access
  - traefik_certs-dumper  # Certificate extraction
```

---

## Troubleshooting Traefik

```bash
# Check Traefik logs
docker logs traefik -f

# Verify router configuration
curl -s http://localhost:8080/api/http/routers | jq

# Check service discovery
docker inspect <container> --format '{{json .Config.Labels}}' | jq

# Test connectivity
curl -I https://app.example.com
```
