# Memory: Template Creation Standards

Guidelines for creating new service templates in `templates/`.

---

## Required Files

Every template **MUST** contain:

| File | Purpose |
|------|---------|
| `docker-compose.<service>.yaml` | Service definition |
| `.env` | Environment variables with defaults |
| `README.md` | Usage documentation |

Optional files:

| File/Directory | Purpose |
|----------------|---------|
| `secrets/` | Pre-configured secret file templates |
| `scripts/` | Init, backup, maintenance scripts |
| `dockerfiles/` | Custom Dockerfiles |

---

## Template YAML Structure

Follow this section order (matching existing templates like `postgresql`):

```yaml
---
services:
  <service>:
    ######################################################################
    # --- CONTAINER BASICS
    ######################################################################
    image: ${<SERVICE>_IMAGE:?Image required}
    container_name: ${APP_NAME:?App name required}-<service>
    hostname: ${APP_NAME}-<service>
    restart: unless-stopped

    ######################################################################
    # --- SECURITY SETTINGS
    ######################################################################
    read_only: true                    # When compatible
    cap_drop:
      - ALL
    cap_add:
      - SETUID
      - SETGID
      - CHOWN
      # Add others only if needed (see memory-security.md)
    security_opt:
      - no-new-privileges:true

    ######################################################################
    # --- SYSTEM RUNTIME
    ######################################################################
    init: true
    stop_grace_period: 30s
    oom_score_adj: -500
    tmpfs:
      - /run
      - /tmp

    ######################################################################
    # --- FILESYSTEM & SECRETS
    ######################################################################
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      # Service-specific volumes...
    secrets:
      - <SERVICE>_PASSWORD

    ######################################################################
    # --- NETWORKING / REVERSE PROXY
    ######################################################################
    networks:
      - backend
      # - frontend  # Only if exposed via Traefik

    ######################################################################
    # --- RUNTIME / ENVIRONMENT
    ######################################################################
    environment:
      # Service-specific variables...
      <SERVICE>_PASSWORD_FILE: /run/secrets/<SERVICE>_PASSWORD
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    healthcheck:
      test: ['CMD-SHELL', '<health-check-command>']
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    stdin_open: false
    tty: false

    ######################################################################
    # --- DEPENDENCIES
    ######################################################################
    # depends_on:
    #   other-service:
    #     condition: service_healthy

    ######################################################################
    # --- SYSTEM LIMITS
    ######################################################################
    # shm_size: "64m"
    # ulimits: ...

volumes:
  <volume-name>:
    driver: local

secrets:
  <SERVICE>_PASSWORD:
    file: ${<SERVICE>_PASSWORD_PATH:?Secret Path required}${<SERVICE>_PASSWORD_FILENAME:?Secret Filename required}

networks:
  backend:
    external: true
```

---

## Template .env Structure

```bash
# === Image Configuration ===
<SERVICE>_IMAGE=<image>:<tag>

# === Secrets Configuration ===
<SERVICE>_PASSWORD_PATH=./secrets/
<SERVICE>_PASSWORD_FILENAME=<SERVICE>_PASSWORD

# === Service-Specific Settings ===
# Document each variable with comments
<SERVICE>_SETTING=default_value  # Description of what this does
```

---

## Chained Dependencies

Templates can declare their own dependencies via `x-required-services`:

```yaml
x-required-services:
  - postgresql    # This template requires postgresql
  - redis         # And redis
```

These are processed recursively by `run.sh`.

---

## Health Check Patterns

### Databases

```yaml
# PostgreSQL
test: ['CMD-SHELL', 'pg_isready -d ${APP_NAME} -U ${APP_NAME}']

# MariaDB/MySQL
test: ['CMD-SHELL', 'mysqladmin ping -h localhost']

# Redis
test: ['CMD-SHELL', 'redis-cli --pass "$$(cat /run/secrets/REDIS_PASSWORD)" ping | grep -q PONG']
```

### Web Services

```yaml
# HTTP endpoint
test: ['CMD-SHELL', 'curl -f http://localhost:8080/health || exit 1']

# TCP port
test: ['CMD-SHELL', 'nc -z localhost 8080']
```

### Background Workers

```yaml
# Process check
test: ['CMD-SHELL', 'pgrep -f "worker" || exit 1']
```

---

## Naming Conventions

| Component | Convention | Example |
|-----------|------------|---------|
| Template folder | `lowercase` or `lowercase_suffix` | `postgresql`, `postgresql_backup` |
| Compose file | `docker-compose.<service>.yaml` | `docker-compose.redis.yaml` |
| Service name | Match folder name | `postgresql`, `redis` |
| Container name | `${APP_NAME}-<service>` | `myapp-postgresql` |
| Volume name | Descriptive lowercase | `database`, `redis`, `appdata` |
| Secret name | `UPPERCASE_SNAKE_CASE` | `POSTGRES_PASSWORD` |

---

## Template README Structure

```markdown
# <Service Name> Template

Brief description of what this template provides.

## Requirements

- List any prerequisites
- Required networks, dependencies

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `<SERVICE>_IMAGE` | `image:tag` | Container image |
| ... | ... | ... |

## Secrets

| Secret | Description |
|--------|-------------|
| `<SERVICE>_PASSWORD` | Main service password |

## Volumes

| Volume | Path | Description |
|--------|------|-------------|
| `<name>` | `/path` | What it stores |

## Usage

\`\`\`yaml
x-required-services:
  - <service>
\`\`\`

## Notes

Any special considerations, known issues, or tips.
```

---

## Validation Checklist

Before committing a new template:

- [ ] YAML validates with `yq eval '.' docker-compose.<service>.yaml`
- [ ] All required variables use `:?Error message` syntax
- [ ] Security settings applied (cap_drop, no-new-privileges)
- [ ] Health check implemented and tested
- [ ] Secrets use `_FILE` suffix pattern
- [ ] Networks correctly assigned (backend/frontend)
- [ ] Logging configured with size limits
- [ ] README.md documents all variables and usage
