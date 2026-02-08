# Memory: Development Workflow

Core principles for working on this repository.

---

## Before Writing Code

### 1. Understand Requirements

- **Read existing code first** before proposing changes
- Analyze current patterns and design decisions
- Ask clarifying questions if anything is unclear
- Never guess at requirements

### 2. Analyze Impact

Before making changes, consider:

- Which files will be affected?
- Could this break existing application stacks?
- Are there template dependencies to consider?
- Will this require updates to multiple places?

### 3. Check Dependencies

```bash
# Check if template is used by any app
grep -r "x-required-services" --include="*.yaml" | grep "<template_name>"

# Check lock files for version info
ls -la <AppName>/.run.conf/.<template>.lock
```

---

## During Implementation

### Minimal Changes Principle

- **Only implement what was requested**
- Do NOT refactor unrelated code
- Preserve existing patterns and design decisions
- If something seems wrong but isn't part of the task: mention it, don't fix it

### What NOT to Do

| Avoid | Reason |
|-------|--------|
| Adding "helpful" features | Scope creep, unexpected behavior |
| Refactoring nearby code | Risk of breaking existing functionality |
| Changing coding style | Inconsistency with rest of codebase |
| Adding extra documentation | Unless explicitly requested |
| Optimizing working code | "If it ain't broke, don't fix it" |

### Validation During Development

```bash
# Validate YAML syntax
yq eval '.' docker-compose.app.yaml > /dev/null

# Check shell script syntax
bash -n run.sh

# Dry run to check behavior
./run.sh <AppName> --dry-run --debug
```

---

## After Implementation

### Self-Review Checklist

- [ ] Only necessary changes made?
- [ ] Existing patterns followed?
- [ ] Security standards applied? (see [memory-security.md](memory-security.md))
- [ ] Naming conventions consistent? (see [memory-conventions.md](memory-conventions.md))
- [ ] YAML validated with `yq`?
- [ ] Shell syntax validated with `bash -n`?

### Testing Changes

1. **Dry run first:**
   ```bash
   ./run.sh <AppName> --dry-run
   ```

2. **Check generated output:**
   ```bash
   yq eval '.' docker-compose.main.yaml
   cat .env
   ```

3. **Test with real deployment:**
   ```bash
   ./run.sh <AppName>
   docker compose -f docker-compose.main.yaml up -d
   docker compose -f docker-compose.main.yaml logs -f
   ```

---

## Commit Guidelines

### Commit Message Format

```
<type>: <short description>

[optional body with more details]

[optional footer with references]
```

### Types

| Type | Usage |
|------|-------|
| `feat` | New feature or template |
| `fix` | Bug fix |
| `docs` | Documentation changes |
| `refactor` | Code restructuring without behavior change |
| `chore` | Maintenance tasks, dependency updates |
| `security` | Security improvements |

### Examples

```
feat: add postgresql_maintenance template

fix: correct volume path in redis template

docs: update CLAUDE.md with new template catalog

security: add read_only filesystem to all database templates
```
