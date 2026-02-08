# Memory: Troubleshooting Standards

Structured approach for diagnosing and resolving issues.

---

## Diagnostic Commands

### Container Status

```bash
# Overview of all containers in stack
docker compose -f docker-compose.main.yaml ps

# Detailed container state
docker inspect <container> --format='{{.State.Status}} - {{.State.Health.Status}}'

# Resource usage
docker stats --no-stream
```

### Logs

```bash
# Follow logs for specific service
docker compose -f docker-compose.main.yaml logs -f <service>

# Last 100 lines
docker compose -f docker-compose.main.yaml logs --tail=100 <service>

# All services
docker compose -f docker-compose.main.yaml logs -f

# run.sh logs
cat <AppName>/.run.conf/logs/latest.log
```

### Configuration Validation

```bash
# Validate generated compose file
yq eval '.' docker-compose.main.yaml

# Check merged environment
grep -v '^#' .env | grep -v '^$' | sort

# Dry run to test run.sh
./run.sh <AppName> --dry-run --debug
```

### Network Diagnostics

```bash
# List networks
docker network ls

# Inspect network
docker network inspect backend

# Check container network assignment
docker inspect <container> --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}'

# Test inter-container connectivity
docker exec <container> ping <other-container>
```

---

## Common Issues

### Container Won't Start

| Symptom | Check | Solution |
|---------|-------|----------|
| `no such image` | Image name/tag | Fix `*_IMAGE` variable in `.env` |
| `permission denied` | File ownership | Check `APP_UID`/`APP_GID`, fix with `chown` |
| `port already in use` | Port conflicts | `lsof -i :<port>`, change port or stop other service |
| `secret not found` | Missing secret file | `./run.sh <App> --generate_password` |

```bash
# Check what's using a port
lsof -i :8080
ss -tlnp | grep 8080
```

### Health Check Failing

| Symptom | Check | Solution |
|---------|-------|----------|
| `unhealthy` | Health check command | Test command manually inside container |
| `starting` (stuck) | Service initialization | Increase `start_period`, check logs |
| Wrong port | Health check target | Verify `TRAEFIK_PORT` matches actual port |

```bash
# Test health check manually
docker exec <container> <health-check-command>

# Example for PostgreSQL
docker exec myapp-postgresql pg_isready -d myapp -U myapp
```

### Permission Denied Errors

```bash
# Check current ownership
ls -la appdata/

# Fix ownership (match APP_UID/APP_GID from .env)
chown -R 1000:1000 appdata/

# Check container user
docker exec <container> id
```

### Network Issues

| Symptom | Check | Solution |
|---------|-------|----------|
| `network not found` | Network exists | `docker network create frontend && docker network create backend` |
| Can't reach database | Network assignment | Ensure both containers on `backend` |
| Traefik can't reach app | Frontend network | Add `frontend` to exposed services |

### Secret/Environment Issues

```bash
# Verify secret file exists
ls -la secrets/

# Check secret is mounted
docker exec <container> ls -la /run/secrets/

# Read secret (careful with logging!)
docker exec <container> cat /run/secrets/POSTGRES_PASSWORD

# Generate missing secrets
./run.sh <AppName> --generate_password
```

### YAML Merge Issues

```bash
# Check x-required-services resolution
yq '.x-required-services[]' docker-compose.app.yaml

# Validate individual template
yq eval '.' templates/<service>/docker-compose.<service>.yaml

# Check for duplicate keys (first wins)
grep -h "^[A-Z]" .env *.env 2>/dev/null | sort | uniq -d
```

---

## Debug Mode

Always try debug mode first for run.sh issues:

```bash
./run.sh <AppName> --debug --dry-run
```

This shows:
- Template processing steps
- File merge operations
- Variable substitutions
- Git sparse checkout details

---

## Log Analysis Patterns

### Error Patterns to Search

```bash
# Common error indicators
docker logs <container> 2>&1 | grep -iE "error|fail|denied|refused|timeout"

# Permission issues
docker logs <container> 2>&1 | grep -i "permission denied"

# Connection issues
docker logs <container> 2>&1 | grep -iE "connection refused|cannot connect|unreachable"

# Secret/password issues
docker logs <container> 2>&1 | grep -iE "authentication|password|credential"
```

### PostgreSQL Specific

```bash
docker logs myapp-postgresql 2>&1 | grep -E "FATAL|ERROR"
```

### Redis Specific

```bash
docker logs myapp-redis 2>&1 | grep -E "ERROR|WARNING"
```

---

## Recovery Procedures

### Restart Stack

```bash
docker compose -f docker-compose.main.yaml down
docker compose -f docker-compose.main.yaml up -d
```

### Force Recreate

```bash
docker compose -f docker-compose.main.yaml up -d --force-recreate
```

### Reset Template (Re-download)

```bash
# Remove lock file
rm -f .run.conf/.<template>.lock

# Re-run with force
./run.sh <AppName> --force
```

### Delete and Rebuild Volumes

```bash
# WARNING: Data loss!
./run.sh <AppName> --delete_volumes

# Then restart
./run.sh <AppName>
docker compose -f docker-compose.main.yaml up -d
```

---

## Validation Checklist

Before reporting an issue:

- [ ] Checked container logs? (`docker logs`)
- [ ] Checked run.sh logs? (`.run.conf/logs/latest.log`)
- [ ] Validated YAML syntax? (`yq eval '.'`)
- [ ] Verified networks exist? (`docker network ls`)
- [ ] Checked secret files exist? (`ls -la secrets/`)
- [ ] Tried debug mode? (`--debug --dry-run`)
- [ ] Tested health check manually?
