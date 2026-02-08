# Memory: Code Conventions

## File Organization

- Templates: `templates/<service>/`
- Application stacks: `<AppName>/`
- Secrets: `<AppName>/secrets/` (gitignored)
- Runtime config: `<AppName>/.run.conf/` (gitignored)
- Persistent data: `<AppName>/appdata/`

## Naming Conventions

### File Names

| Type | Convention | Example |
|------|------------|---------|
| Service templates | `docker-compose.<service>.yaml` | `docker-compose.postgresql.yaml` |
| Main compose file | `docker-compose.main.yaml` | - |
| App compose file | `docker-compose.app.yaml` | - |
| Environment files | `.env` | - |
| Lock files | `.run.conf/.<template>.lock` | `.run.conf/.postgresql.lock` |

### Shell Scripts

| Type | Convention | Example |
|------|------------|---------|
| Variables (local) | `lowercase_snake_case` | `local_var`, `temp_file` |
| Variables (exported) | `UPPERCASE_SNAKE_CASE` | `APP_NAME`, `DEBUG` |
| Functions | `lowercase_snake_case` | `log_info()`, `copy_required_services()` |
| Constants | `UPPERCASE_SNAKE_CASE` | `MAX_LOG_FILES`, `VERSION` |

### Docker Compose

| Type | Convention | Example |
|------|------------|---------|
| Service names | lowercase | `postgresql`, `redis`, `authentik-worker` |
| Container names | `${APP_NAME}` pattern | `${APP_NAME:-myapp}` |
| Volume names | lowercase | `database`, `redis`, `appdata` |
| Network names | lowercase | `frontend`, `backend` |
| Secret names | `UPPERCASE_SNAKE_CASE` | `POSTGRES_PASSWORD`, `REDIS_PASSWORD` |

### Environment Variables

| Type | Convention | Example |
|------|------------|---------|
| Image references | `*_IMAGE` suffix | `POSTGRES_IMAGE`, `REDIS_IMAGE` |
| File paths | `*_PATH` suffix | `POSTGRES_PASSWORD_PATH` |
| File names | `*_FILENAME` suffix | `POSTGRES_PASSWORD_FILENAME` |
| Boolean flags | Descriptive name | `ENABLE_BACKUP=true` |
| Port numbers | `*_PORT` suffix | `TRAEFIK_PORT`, `APP_PORT` |

## Code Style

- Validate YAML with `yq` before saving
- Follow existing patterns in the repository
- Use meaningful variable names
- Keep scripts modular and well-documented

## Comments

### Shell Scripts

- Explain **WHY**, not **WHAT**
- Document workarounds with context
- Add function headers for complex logic:

```bash
# Copies required service templates from Git repository
# Processes x-required-services chain recursively
# Args: $1 - project directory
# Returns: 0 on success, 1 on failure
copy_required_services() {
```

### Docker Compose YAML

- Use `# ---` separators for logical sections
- Document non-obvious environment variables
- Explain capability requirements:

```yaml
cap_add:
  - CHOWN  # Required: container changes file ownership on startup
```

### Environment Files

- Group related variables with comment headers
- Document default values and valid options:

```bash
# === Database Configuration ===
POSTGRES_IMAGE=postgres:15  # Options: postgres:14, postgres:15, postgres:16
POSTGRES_BACKUP_KEEP=7      # Number of backups to retain
```
