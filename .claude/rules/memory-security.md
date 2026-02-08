# Memory: Security Hardening Standards

**CRITICAL:** Security hardening is **mandatory** for all Docker containers. Apply these standards to every new service.

## Credentials & Secrets

- **Never** use plain environment variables for secrets
- **Always** use Docker Secrets (file-based)
- Store secrets in `<AppName>/secrets/` directory (gitignored, 600 permissions)
- Reference via `_FILE` suffix pattern: `POSTGRES_PASSWORD_FILE=/run/secrets/POSTGRES_PASSWORD`
- Generate passwords with: `./run.sh <App> --generate_password [file] [length]`

## Input Validation (Shell Scripts)

### Always Validate User Input

```bash
# Validate directory exists
[[ -d "$1" ]] || { log_error "Directory not found: $1"; exit 1; }

# Validate required variables
: "${APP_NAME:?APP_NAME is required}"

# Validate file exists and is readable
[[ -r "$config_file" ]] || { log_error "Cannot read: $config_file"; return 1; }

# Sanitize paths (prevent directory traversal)
project_dir="$(realpath "$1")"
```

### Never Trust External Data

- Validate YAML structure before processing with `yq`
- **Always quote variables** in commands: `"$var"` not `$var`
- Use `--` to separate options from arguments in commands
- Escape special characters when constructing commands

### Safe Command Construction

```bash
# Good: Quoted variables
docker compose -f "$compose_file" up -d

# Bad: Unquoted (shell injection risk)
docker compose -f $compose_file up -d

# Good: Using -- to prevent option injection
grep -- "$pattern" "$file"
```

---

## Container Hardening - Mandatory Configuration

Apply these security settings to **ALL** containers:

### 1. Capabilities (Defense in Depth)

```yaml
cap_drop:
  - ALL  # Drop all capabilities by default

cap_add:  # Add ONLY the minimum required capabilities
  # Common minimal set for databases/services:
  - SETUID   # Required for user context switching
  - SETGID   # Required for group management
  - CHOWN    # Required for file ownership changes
  # Only if needed:
  # - DAC_OVERRIDE  # Read/write files owned by different users
  # - FOWNER        # Bypass permission checks on file operations
  # - NET_BIND_SERVICE  # Bind to ports < 1024
```

### 2. Privilege Escalation Prevention

```yaml
security_opt:
  - no-new-privileges:true  # Mandatory: prevent privilege escalation
  - apparmor=${APPARMOR_PROFILE:-docker-default}  # Mandatory: AppArmor confinement
```

**Custom AppArmor Profile (optional):**

For services requiring stricter confinement than `docker-default`:

```bash
# Create profile: /etc/apparmor.d/docker-myapp
#include <tunables/global>

profile docker-myapp flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  # Allow network access
  network inet stream,
  network inet6 stream,

  # Allow read access to app directory
  /app/** r,
  /app/bin/* ix,

  # Writable paths (match tmpfs mounts)
  /tmp/** rw,
  /run/** rw,

  # Deny sensitive paths
  deny /etc/shadow r,
  deny /root/** rwx,
  deny /proc/*/mem rw,
}

# Load profile
sudo apparmor_parser -r /etc/apparmor.d/docker-myapp

# Use in .env
APPARMOR_PROFILE=docker-myapp
```

**When to use custom profiles:**
- Services handling untrusted input (file uploads, user content)
- Public-facing APIs without authentication layer
- Containers with elevated capabilities (NET_BIND_SERVICE, etc.)

### 3. Read-Only Filesystem (When Possible)

```yaml
read_only: true  # Enable for stateless services & databases

tmpfs:  # Required writable paths for read_only:true
  - /run
  - /tmp
  - /var/tmp
  # Add service-specific paths as needed:
  # - /var/log  # If logs can't go to stdout
  # - /var/cache
```

**When NOT to use `read_only: true`:**
- baseimage-docker containers (need `/etc/service/`, `/etc/container_environment.sh`)
- Containers with buggy internal permission management
- Complex multi-process containers with unclear write requirements

### 4. Non-Root User (Preferred)

```yaml
user: "${APP_UID:-1000}:${APP_GID:-1000}"  # Run as non-root when possible
```

**When to skip:**
- Container's official image handles user switching internally (check docs)
- Image has `NON_ROOT` environment variable (use that instead)
- Internal user management causes permission issues

### 5. System Runtime Hardening

```yaml
init: true  # PID 1 is tini – handles zombies properly
stop_grace_period: 30s  # Graceful shutdown
oom_score_adj: -500  # Reduce likelihood of OOM killer
```

### 6. Resource Limits (Recommended)

```yaml
# Uncomment and adjust based on workload:
# mem_limit: ${MEM_LIMIT:-512m}
# cpus: ${CPU_LIMIT:-1.0}
# pids_limit: ${PIDS_LIMIT:-128}
```

## Network Isolation

- **frontend** network: Reverse proxy only (Traefik, Nginx)
- **backend** network: Application services, databases, caches
- **Never** expose databases/caches to frontend network
- Create networks before first use: `docker network create frontend && docker network create backend`

## Practical Implementation Guide

### Step-by-Step Hardening Process

1. **Start with capabilities:**
   - Add `cap_drop: ALL` first
   - Add `cap_add` with minimal set (SETUID, SETGID, CHOWN)
   - Test if container starts
   - Add more capabilities ONLY if needed

2. **Add security options:**
   - `no-new-privileges:true` (always safe)
   - AppArmor profile (always safe)

3. **Try read-only filesystem:**
   - Add `read_only: true`
   - Add required tmpfs mounts
   - Check logs for "Read-only file system" errors
   - Add additional tmpfs mounts or revert if incompatible

4. **Consider non-root user:**
   - Check if image supports `user:` directive
   - Or use `NON_ROOT=true` environment variable
   - Test file permissions on volumes
   - Revert if internal permission management fails

### Known Compatibility Issues

**baseimage-docker (phusion/baseimage):**
- ❌ NOT compatible with `read_only: true`
- Reason: Writes to `/etc/service/`, `/etc/container_environment.sh`
- Examples: Seafile, SeaDoc (v13.0.15)

**Seafile NON_ROOT feature (v13.0.15):**
- ❌ Buggy: internal scripts lack execute permissions
- Error: `Permission denied: /opt/seafile/seafile-server-*/seafile.sh`
- Workaround: Use root with minimal capabilities instead

## Reference: Security Levels

**Level 1 (Minimum):** cap_drop: ALL + minimal cap_add + no-new-privileges
**Level 2 (Standard):** Level 1 + AppArmor + non-root user
**Level 3 (Maximum):** Level 2 + read_only filesystem + tmpfs

**Target:** Achieve Level 2 minimum, Level 3 where compatible

## Validation Commands

```bash
# Check capabilities
docker inspect <container> --format '{{.HostConfig.CapDrop}} | {{.HostConfig.CapAdd}}'

# Check read-only status
docker inspect <container> --format '{{.HostConfig.ReadonlyRootfs}}'

# Check user
docker exec <container> whoami
docker exec <container> id

# Test functionality
docker logs <container> | grep -i "error\|permission denied"
```

## Security Audit Commands

### Full Stack Audit

```bash
# List all containers with their security settings
docker ps --format "{{.Names}}" | while read container; do
  echo "=== $container ==="

  # Check if running as root
  user=$(docker inspect --format='{{.Config.User}}' "$container")
  if [[ -z "$user" || "$user" == "root" || "$user" == "0" ]]; then
    echo "  ⚠ User: root (consider non-root)"
  else
    echo "  ✓ User: $user"
  fi

  # Check read-only filesystem
  ro=$(docker inspect --format='{{.HostConfig.ReadonlyRootfs}}' "$container")
  [[ "$ro" == "true" ]] && echo "  ✓ Read-only: enabled" || echo "  ⚠ Read-only: disabled"

  # Check no-new-privileges
  nnp=$(docker inspect --format='{{.HostConfig.SecurityOpt}}' "$container")
  [[ "$nnp" == *"no-new-privileges"* ]] && echo "  ✓ No-new-privileges: enabled" || echo "  ⚠ No-new-privileges: missing"

  # Check capabilities
  caps=$(docker inspect --format='{{.HostConfig.CapDrop}}' "$container")
  [[ "$caps" == *"ALL"* ]] && echo "  ✓ Cap-drop: ALL" || echo "  ⚠ Cap-drop: incomplete"

  echo ""
done
```

### Quick Security Check (Single Container)

```bash
# One-liner for quick assessment
docker inspect <container> --format '
User: {{.Config.User}}
ReadOnly: {{.HostConfig.ReadonlyRootfs}}
CapDrop: {{.HostConfig.CapDrop}}
CapAdd: {{.HostConfig.CapAdd}}
SecurityOpt: {{.HostConfig.SecurityOpt}}
Networks: {{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}'
```

### Verify Secrets Are Not in Environment

```bash
# Check for exposed secrets in environment variables (should be empty for sensitive data)
docker inspect <container> --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -iE "password|secret|key|token" || echo "✓ No secrets in plain env vars"

# Verify secrets are mounted
docker exec <container> ls -la /run/secrets/ 2>/dev/null || echo "⚠ No secrets mounted"
```

### Network Isolation Check

```bash
# Verify database containers are NOT on frontend network
docker network inspect frontend --format '{{range .Containers}}{{.Name}} {{end}}' | grep -E "postgres|mysql|mariadb|redis|mongo" && echo "⚠ Database exposed to frontend!" || echo "✓ Databases isolated from frontend"
```