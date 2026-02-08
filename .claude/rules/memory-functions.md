# Memory: Shell Function Guidelines

Guidelines for writing and maintaining shell functions in this repository.

---

## Function Structure

### Keep Functions Focused

- One function = One responsibility
- Target max ~50 lines per function (split if larger)
- Clear input/output contract
- Single level of abstraction

### Function Header Template

```bash
# Brief description of what this function does
#
# Globals:
#   VARIABLE_NAME - Description of global variable used
# Arguments:
#   $1 - Description of first argument
#   $2 - Description of second argument (optional, default: value)
# Outputs:
#   Writes to stdout: description
#   Writes to stderr: error messages
# Returns:
#   0 - Success
#   1 - Failure with description
function_name() {
    local arg1="$1"
    local arg2="${2:-default}"
    ...
}
```

### Parameter Handling

```bash
# Good: Named local variables at function start
process_template() {
    local template_name="$1"
    local target_dir="$2"
    local force="${3:-false}"

    # Use named variables throughout
    log_info "Processing $template_name to $target_dir"
}

# Bad: Using positional parameters throughout
process_template() {
    log_info "Processing $1 to $2"  # Unclear what $1 and $2 are
}
```

---

## Return Values & Output

### Return Codes

- Use `return 0` for success
- Use `return 1` for failure
- Use specific codes (2, 3, ...) for distinct failure modes if needed

### Output Streams

| Stream | Usage |
|--------|-------|
| `stdout` | Data output (for piping/capturing) |
| `stderr` | Error messages, warnings, debug info |

```bash
# Good: Separate data from messages
get_container_id() {
    local name="$1"
    local id

    id=$(docker ps -qf "name=$name" 2>/dev/null)
    if [[ -z "$id" ]]; then
        echo "Container not found: $name" >&2  # Error to stderr
        return 1
    fi

    echo "$id"  # Data to stdout
}

# Usage: Can capture output cleanly
container_id=$(get_container_id "myapp") || exit 1
```

---

## Error Handling

### Always Check Command Results

```bash
# Using if statement
if ! yq eval '.services' "$compose_file" > /dev/null 2>&1; then
    log_error "Invalid YAML: $compose_file"
    return 1
fi

# Using || for inline handling
cd "$target_dir" || { log_error "Cannot enter: $target_dir"; return 1; }
```

### Use Trap for Cleanup

```bash
process_with_temp_files() {
    local temp_file
    temp_file=$(mktemp)

    # Cleanup on exit (success or failure)
    trap 'rm -f "$temp_file"' EXIT

    # Do work with temp_file
    echo "data" > "$temp_file"
    process "$temp_file"
}
```

### Fail Fast

```bash
# At script level (optional, use with caution)
set -euo pipefail

# Per-command (preferred for more control)
command || { log_error "Command failed"; exit 1; }
```

---

## Logging Standards

Use the existing logging functions consistently:

| Function | Color | Usage |
|----------|-------|-------|
| `log_ok` | Green | Success messages, completion confirmations |
| `log_info` | Cyan | Informational messages, progress updates |
| `log_warn` | Yellow | Warnings, non-critical issues |
| `log_error` | Red | Errors, failures |
| `log_debug` | Grey | Debug output (only with `--debug` flag) |

### Logging Best Practices

```bash
# Good: Informative messages
log_info "Copying template: $template_name"
log_ok "Template copied successfully"
log_warn "Lock file missing, will create new one"
log_error "Failed to parse YAML: $compose_file"
log_debug "Raw yq output: $output"

# Bad: Vague messages
log_info "Processing..."
log_error "Error"
```

---

## Common Patterns

### Optional Arguments with Defaults

```bash
my_function() {
    local required_arg="$1"
    local optional_arg="${2:-default_value}"
    local flag="${3:-false}"
    ...
}
```

### Flag Parsing

```bash
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug)
                DEBUG=true
                shift
                ;;
            --force|-f)
                FORCE=true
                shift
                ;;
            --output|-o)
                OUTPUT="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                return 1
                ;;
            *)
                POSITIONAL+=("$1")
                shift
                ;;
        esac
    done
}
```

### Safe File Operations

```bash
# Check before operating
[[ -f "$file" ]] || { log_error "File not found: $file"; return 1; }
[[ -r "$file" ]] || { log_error "Cannot read: $file"; return 1; }
[[ -w "$dir" ]]  || { log_error "Cannot write to: $dir"; return 1; }

# Create parent directories
mkdir -p "$(dirname "$target_file")"

# Safe move/copy (don't overwrite without asking)
[[ -f "$target" && "$FORCE" != "true" ]] && {
    log_warn "Target exists: $target (use --force to overwrite)"
    return 1
}
```

---

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| `cd` without error check | Silently continues in wrong dir | `cd "$dir" \|\| return 1` |
| Unquoted variables | Word splitting, glob expansion | Always quote: `"$var"` |
| `cat file \| grep` | Useless use of cat | `grep pattern file` |
| Global variables everywhere | Hard to track state | Use local variables |
| Deep nesting (>3 levels) | Hard to read and maintain | Extract to functions |
| Long pipelines | Hard to debug | Break into steps with variables |
