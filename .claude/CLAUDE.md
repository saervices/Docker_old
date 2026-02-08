# CLAUDE.md - Docker Template System

## Project Overview

**Purpose:** Template-based Docker Compose management for self-hosted infrastructure.

**Core Mechanism:** Services declare dependencies via `x-required-services` YAML extension. `run.sh` automatically merges templates into `docker-compose.main.yaml`.

```yaml
# Example: App declares dependencies
x-required-services:
  - postgresql
  - redis
```

---

## Rules Index

Detailed guidelines are organized in separate rule files:

| Rule File | Content |
|-----------|---------|
| [memory-language.md](rules/memory-language.md) | Language preferences (German chat, English code) |
| [memory-conventions.md](rules/memory-conventions.md) | Naming conventions, file organization, comments |
| [memory-security.md](rules/memory-security.md) | Container hardening, secrets, input validation |
| [memory-workflow.md](rules/memory-workflow.md) | Before/during/after coding workflow |
| [memory-functions.md](rules/memory-functions.md) | Shell function guidelines, patterns |
| [memory-templates.md](rules/memory-templates.md) | Template creation standards, YAML structure |
| [memory-traefik.md](rules/memory-traefik.md) | Reverse proxy integration, middlewares |
| [memory-troubleshooting.md](rules/memory-troubleshooting.md) | Diagnostics, common issues, recovery |
| [memory-maintenance.md](rules/memory-maintenance.md) | Updates, backups, rule maintenance |

---

## Directory Structure

```
/mnt/data/Github/Docker/
├── run.sh                    # Main orchestration script
├── get-folder.sh             # Template downloader
├── templates/                # 15+ reusable service templates
│   ├── postgresql/
│   ├── redis/
│   ├── mariadb/
│   └── ...
├── app_template/             # Reference for new apps
└── <AppName>/                # Application stacks
    ├── docker-compose.app.yaml
    ├── .env
    ├── secrets/              # Credentials (gitignored)
    ├── appdata/              # Persistent data
    └── .run.conf/            # Runtime config (gitignored)
```

---

## Essential Commands

```bash
# Initial setup
./run.sh <AppName>

# Update templates
./run.sh <AppName> --force

# Update images & restart
./run.sh <AppName> --update

# Generate secrets
./run.sh <AppName> --generate_password

# Debug mode
./run.sh <AppName> --debug --dry-run

# Start/stop stack
docker compose -f docker-compose.main.yaml up -d
docker compose -f docker-compose.main.yaml down

# View logs
docker compose -f docker-compose.main.yaml logs -f [service]
```

---

## Quick Reference

### run.sh Options

| Option | Description |
|--------|-------------|
| `--debug` | Verbose logging |
| `--dry-run` | Simulate without changes |
| `--force` | Overwrite existing files |
| `--update` | Pull images, restart if changed |
| `--delete_volumes` | Remove Docker volumes |
| `--generate_password [file] [len]` | Generate secrets |

### Key Concepts

| Concept | Description |
|---------|-------------|
| `x-required-services` | YAML extension to declare template dependencies |
| `docker-compose.main.yaml` | Generated merged compose file |
| `.run.conf/.<template>.lock` | Version lock files (git hashes) |
| `secrets/` | File-based Docker secrets |
| `frontend` / `backend` | Docker networks for isolation |

### File Naming

| Type | Name |
|------|------|
| App compose | `docker-compose.app.yaml` |
| Template compose | `docker-compose.<service>.yaml` |
| Generated output | `docker-compose.main.yaml` |

---

## Dependencies

- `yq` - YAML processor (https://github.com/mikefarah/yq)
- `git` - For sparse checkout of templates
- `docker` + `docker compose` - Container runtime

---

## Network Setup (One-Time)

```bash
docker network create frontend
docker network create backend
```

---

## Repository Metadata

| Property | Value |
|----------|-------|
| Path | `/mnt/data/Github/Docker/` |
| Main script | `run.sh` |
| Templates | `templates/` (15+ services) |
| App stacks | 8 instances |
