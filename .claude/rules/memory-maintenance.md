# Memory: Maintenance & Updates

Guidelines for maintaining the Docker Template System and keeping rules up-to-date.

---

## Image Updates

### Update All Images in a Stack

```bash
./run.sh <AppName> --update
```

This will:
1. Pull latest images for all services
2. Compare image IDs with running containers
3. Restart only if images changed

### Manual Image Update

```bash
# Pull specific image
docker pull postgres:16

# Update .env with new tag
POSTGRES_IMAGE=postgres:16

# Recreate container
docker compose -f docker-compose.main.yaml up -d --force-recreate postgresql
```

---

## Template Updates

### Force Re-Download Templates

```bash
# Remove lock file for specific template
rm -f .run.conf/.postgresql.lock

# Re-run with force
./run.sh <AppName> --force
```

### Update All Templates

```bash
# Remove all lock files
rm -f .run.conf/.*lock

# Force update
./run.sh <AppName> --force
```

### Check Template Version

```bash
# View current lock (contains git commit hash)
cat .run.conf/.postgresql.lock
```

---

## Breaking Changes

When a template or script has breaking changes:

1. **Document in template README.md:**
   ```markdown
   ## Breaking Changes

   ### v2.0 (2024-01)
   - Changed: `POSTGRES_PASSWORD` → `POSTGRES_PASSWORD_FILE`
   - Removed: `POSTGRES_USER` (now derived from APP_NAME)
   ```

2. **Log warning in run.sh** (if detectable)

3. **Provide migration steps**

---

## Rule Maintenance

### When to Update Rules

| Event | Action |
|-------|--------|
| New template created | Update `memory-templates.md` if patterns change |
| Security practice changes | Update `memory-security.md` |
| New naming convention | Update `memory-conventions.md` |
| New Traefik middleware | Update `memory-traefik.md` |
| Script behavior changes | Update `memory-functions.md` |

### Rule File Structure

```
.claude/rules/
├── memory-language.md        # When to update: Language policy changes
├── memory-conventions.md     # When to update: New naming patterns
├── memory-security.md        # When to update: Security requirements change
├── memory-workflow.md        # When to update: Development process changes
├── memory-functions.md       # When to update: Shell patterns evolve
├── memory-templates.md       # When to update: Template structure changes
├── memory-traefik.md         # When to update: Proxy config patterns change
├── memory-troubleshooting.md # When to update: New common issues found
└── memory-maintenance.md     # This file
```

### Keep CLAUDE.md in Sync

When adding/removing rule files:
1. Update the rules index table in `CLAUDE.md`
2. Update directory structure if needed

---

## Backup Before Major Changes

### Manual Backup

```bash
# Backup entire app directory
tar -czf backup-$(date +%Y%m%d).tar.gz <AppName>/

# Backup only config
tar -czf config-backup.tar.gz <AppName>/.env <AppName>/docker-compose.*.yaml
```

### Automatic Backups

`run.sh` creates backups in `.run.conf/.backups/` before merging:
- Timestamped copies of `.env`
- Timestamped copies of compose files

---

## Health Checks

### Verify Stack Health

```bash
# All containers healthy?
docker compose -f docker-compose.main.yaml ps

# Specific service
docker inspect <container> --format='{{.State.Health.Status}}'
```

### Verify Configuration

```bash
# YAML valid?
yq eval '.' docker-compose.main.yaml > /dev/null && echo "OK"

# Environment complete?
grep -E "^\w+=$" .env  # Shows empty variables

# Secrets exist?
ls -la secrets/
```

---

## Scheduled Maintenance

### Weekly

- [ ] Check `docker system df` for disk usage
- [ ] Review container logs for errors
- [ ] Verify backups are running (if using backup templates)

### Monthly

- [ ] Check for image updates: `docker images --format "{{.Repository}}:{{.Tag}}" | xargs -I{} docker pull {}`
- [ ] Review security advisories for base images
- [ ] Clean unused images: `docker image prune -a`

### Quarterly

- [ ] Review and update rule files if needed
- [ ] Check for deprecated Docker Compose syntax
- [ ] Audit secret rotation
