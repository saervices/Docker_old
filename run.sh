#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Constants & Defaults
# ──────────────────────────────────────────────────────────────────────────────
# Get the directory of the script itself and the script name without .sh suffix
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
readonly SCRIPT_BASE="$(basename "${BASH_SOURCE[0]}" .sh)"

# ──────────────────────────────────────────────────────────────────────────────
# Logging Setup & Functions
# ──────────────────────────────────────────────────────────────────────────────

# Color codes for logging
# ───────────────────────────────────────
RESET='\033[0m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
GREY='\033[1;30m'
MAGENTA='\033[0;35m'

# Function: log_ok
# ${GREEN}[OK]
# ───────────────────────────────────────
log_ok() {
  local msg="$*"
  echo -e "${GREEN}[OK]${RESET}    $msg"
  if [[ -n "${LOGFILE:-}" ]]; then
    echo -e "[OK]    $msg" >> "$LOGFILE"
  fi
}

# Function: log_info
# ${CYAN}[INFO]
# ───────────────────────────────────────
log_info() {
  local msg="$*"
  echo -e "${CYAN}[INFO]${RESET}  $msg"
  if [[ -n "${LOGFILE:-}" ]]; then
    echo -e "[INFO]  $msg" >> "$LOGFILE"
  fi
}

# Function: log_warn
# ${YELLOW}[WARN]
# ───────────────────────────────────────
log_warn() {
  local msg="$*"
  echo -e "${YELLOW}[WARN]${RESET}  $msg" >&2
  if [[ -n "${LOGFILE:-}" ]]; then
    echo -e "[WARN]  $msg" >> "$LOGFILE"
  fi
}

# Function: log_error
# ${RED}[ERROR]
# ───────────────────────────────────────
log_error() {
  local msg="$*"
  echo -e "${RED}[ERROR]${RESET} $msg" >&2
  if [[ -n "${LOGFILE:-}" ]]; then
    echo -e "[ERROR] $msg" >> "$LOGFILE"
  fi
}

# Function: log_debug
# ${GREY}[DEBUG]
# ───────────────────────────────────────
log_debug() {
  local msg="$*"
  if [[ "${DEBUG:-false}" == true ]]; then
    echo -e "${GREY}[DEBUG]${RESET} $msg"
    if [[ -n "${LOGFILE:-}" ]]; then
      echo -e "[DEBUG] $msg" >> "$LOGFILE"
    fi
  fi
}

# Function: setup_logging
# Initializes logging file inside TARGET_DIR
# Keep only the latest $log_retention_count logs
# ───────────────────────────────────────
setup_logging() {
  local log_retention_count="${1:-2}"

  # Construct log dir path
  local log_dir="${SCRIPT_DIR}/${TARGET_DIR}/.${SCRIPT_BASE}.conf/logs"

  # Ensure log dir exists and assign logfile
  LOGFILE="${log_dir}/$(date +%Y%m%d-%H%M%S).log"
  ensure_dir_exists "$log_dir"

  # Symlink latest.log to current log
  touch "$LOGFILE" && sleep 0.2
  ln -sf "$LOGFILE" "$log_dir/latest.log"

  # Retain only the latest N logs
  local logs  
  mapfile -t logs < <(
  find "$log_dir" -maxdepth 1 -type f -name '*.log' -printf "%T@ %p\n" |
  sort -nr | cut -d' ' -f2- | tail -n +$((log_retention_count + 1))
  )

  for old_log in "${logs[@]}"; do
    rm -f "$old_log"
  done
}

# ──────────────────────────────────────────────────────────────────────────────
# Global Function Helpers
# ──────────────────────────────────────────────────────────────────────────────

# Function: usage
# Displays help and usage information
# ───────────────────────────────────────
usage() {
  echo ""
  echo "Usage: ./$SCRIPT_BASE.sh <project_folder> [options]"
  echo ""
  echo "Options:"
  echo "  --debug                  Enable debug logging"
  echo "  --dry-run                Simulate actions without executing"
  echo "  --force                  Force overwrite of existing files"
  echo "  --update                 Force update of template repo"
  echo "  --delete_volumes         Delete associated Docker volumes for the project"
  echo "  --generate_password [file] [length]"
  echo "                           Generate a secure password"
  echo "                           → Optional: file to write into secrets/"
  echo "                           → Optional: length (default: 32)"
  echo ""
  echo "Examples:"
  echo "  ./$SCRIPT_BASE.sh Authentik --generate_password"
  echo "  ./$SCRIPT_BASE.sh Authentik --generate_password admin_password.txt"
  echo "  ./$SCRIPT_BASE.sh Authentik --generate_password admin_password.txt 64"
  echo ""
}

# Function: install_dependency
# Installs a dependency using apt, yum or from a custom URL
# ───────────────────────────────────────
install_dependency() {
  local name="$1"
  local url="${2:-}"
  
  if [[ "$DRY_RUN" == true ]]; then
    log_info "Dry-run: skipping actual installation of '$name'."
    return 0
  fi

  # Always install yq via URL (binary)
  if [[ "$name" == "yq" && -n "$url" ]]; then
    sudo wget -q -O "/usr/local/bin/yq" "$url"
    sudo chmod +x "/usr/local/bin/yq"
    log_info "Installed yq via direct binary download."
    return 0
  fi

  # Install other tools via package manager
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq &>/dev/null && sudo apt-get install -y -qq "$name" &>/dev/null
  elif command -v yum &>/dev/null; then
    sudo yum install -y "$name" -q -e 0 &>/dev/null
  else
    log_error "No supported package manager available for '$name'."
    return 1
  fi

  log_info "$name installed successfully."
}

# Ensure a directory exists (create if missing)
# Arguments:
#   $1 - directory path
# ───────────────────────────────────────
ensure_dir_exists() {
  local dir="$1"

  if [[ -z "$dir" ]]; then
    log_error "ensure_dir_exists() called with empty path"
    return 1
  fi

  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir" || {
      log_error "Failed to create directory: $dir"
      return 1
    }
    log_info "Created directory: $dir"
  else
    log_debug "Directory already exists: $dir"
  fi
}

# Function: copy_file
# Copy a file to a target location, overwriting if exists.
# Supports DRY_RUN to simulate the operation.
# ─────────────────────────────────────────────────────────────
copy_file() {
  local src_file="$1"
  local dest_file="$2"

  if [[ -z "$src_file" || -z "$dest_file" ]]; then
    log_error "Missing arguments: src_file, dest_file"
    return 1
  fi

  if [[ ! -f "$src_file" ]]; then
    log_error "Source file '$src_file' does not exist"
    return 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_info "Dry-run: would copy '$src_file' to '$dest_file'"
    return 0
  fi

  if cp -- "$src_file" "$dest_file"; then
    log_info "Copied file: '$src_file' → '$dest_file'"
  else
    log_error "Failed to copy file '$src_file' to '$dest_file'"
    return 1
  fi
}

# Function: merge_subfolders_from
# Copy all subfolders from a matched source folder into a destination folder.
# Existing folders will be merged (new files added, nothing overwritten).
# Supports DRY_RUN to simulate the operation.
# ───────────────────────────────────────────────────────────────────────
merge_subfolders_from() {
  local src_root="$1"
  local match_name="$2"
  local dest_root="$3"

  # check all required params
  if [[ -z "$src_root" || -z "$match_name" || -z "$dest_root" ]]; then
    log_error "Missing arguments: src_root, match_name, dest_root"
    return 1
  fi

  local matched_path="$src_root/$match_name"

  if [[ ! -d "$matched_path" ]]; then
    log_error "Source folder '$matched_path' not found"
    return 1
  fi

  ensure_dir_exists "$dest_root"

  for subdir in "$matched_path"/*/; do
    [[ -d "$subdir" ]] || continue
    local name
    name="$(basename "$subdir")"
    local target="$dest_root/$name"
    ensure_dir_exists "$target"

    if [[ "$DRY_RUN" == true ]]; then
      log_info "Dry-run: would merge contents of '$subdir' into '$target' (no overwrite)"
    else
      # Copy contents of $subdir into $target (no overwrite)
      rsync -a --ignore-existing "${subdir%/}/" "$target/"
      if [[ $? -ne 0 ]]; then
        log_error "rsync failed copying from '$subdir' to '$target'"
        return 1
      fi
      log_info "Merged contents of '$subdir' into '$target' (no overwrite)"
    fi
  done

  return 0
}

# Function: setup_cleanup_trap
# Register EXIT trap to clean up temporary folder
# ────────────────────────────────────────────────
setup_cleanup_trap() {
  trap '[[ -d "$TMPDIR" ]] && rm -rf -- "$TMPDIR"' EXIT
  log_debug "Removed tmp directory: $TMPDIR"
}

# Function: process_merge_file
# Merges a key=value file into a target file without overwriting existing keys.
# Supports dry-run mode and comment/blank-line preservation.
# ────────────────────────────────────────────────
process_merge_file() {
  local file="$1"
  local output_file="$2"
  local -n seen_vars_ref="$3"

  if [[ -z "$3" ]]; then
    log_error "Third argument (reference name) missing."
    return 1
  fi

  if ! declare -p "$3" 2>/dev/null | grep -q 'declare -A'; then
    log_error "Variable '$3' is not declared as associative array."
    return 1
  fi

  if [[ -z "$file" || -z "$output_file" ]]; then
    log_error "Missing arguments: file, output_file, seen_vars_ref"
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    log_warn "File '$file' not found, skipping."
    return 0
  fi

  local source_name
  source_name="$(basename "$file")"

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Preserve comments and blank lines
    if [[ "$line" =~ ^#.*$ || -z "$line" ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        log_info "Would preserve comment/blank: $line"
      else
        echo "$line" >> "$output_file"
      fi
      continue
    fi

    local key="${line%%=*}"
    if [[ -z "$key" ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        log_info "Would preserve malformed line: $line"
      else
        echo "$line" >> "$output_file"
      fi
      continue
    fi

    if [[ -n "$key" && -n "${seen_vars_ref[$key]:-}" ]]; then
      log_warn "Duplicate variable '$key' found in $source_name (already from ${seen_vars_ref[$key]}), skipping."
    else
      seen_vars_ref["$key"]="$source_name"
      line="$(echo "$line" | sed -E 's/^[[:space:]]*([^=[:space:]]+)[[:space:]]*=[[:space:]]*(.*)$/\1=\2/')"

      if [[ "$DRY_RUN" == true ]]; then
        log_info "Would add: $line"
      else
        echo "$line" >> "$output_file"
      fi
    fi
  done < "$file"

  if [[ "$DRY_RUN" != true ]]; then
    echo "" >> "$output_file"  # blank line for clarity
    log_info "Merged $file into $output_file"
  fi
}

# Function: process_merge_yaml_file
# Merges a single docker-compose YAML file into a target YAML file using yq.
# Applies key-by-key merging logic with override behavior.
# Preserves structure and formatting, skipping x-required-services and comments.
# Supports dry-run mode.
# ────────────────────────────────────────────────
process_merge_yaml_file() {
  local source_file="$1"
  local target_file="$2"

  [[ ! -f "$source_file" ]] && {
    log_error "Source compose file not found: $source_file"
    return 1
  }

  local tmp_src="${TMPDIR}/process_merge_yaml_file_src_$$.yaml"
  local tmp_tgt="${TMPDIR}/process_merge_yaml_file_tgt_$$.yaml"

  # Clean files: strip x-required-services, comments, ---
  yq 'del(.["x-required-services"])' "$source_file" | sed '/^---$/d' | sed 's/\s*#.*$//' > "$tmp_src"

  if [[ -f "$target_file" ]]; then
    yq '.' "$target_file" | sed '/^---$/d' | sed 's/\s*#.*$//' > "$tmp_tgt"
  else
    : > "$tmp_tgt"
  fi

  MERGE_INPUTS=("$tmp_tgt" "$tmp_src")

  merge_key() {
    local key="$1"
    local files=("${MERGE_INPUTS[@]}")
    yq eval-all "select(has(\"$key\")) | .$key" "${files[@]}" |
      yq eval-all 'select(tag == "!!map") | . as $item ireduce ({}; . * $item)' -
  }

  services=$(merge_key services)
  volumes=$(merge_key volumes)
  secrets=$(merge_key secrets)
  networks=$(merge_key networks)

  if [[ "${DRY_RUN:-false}" == true ]]; then
    log_info "Dry-run: skipping write of merged compose file $target_file"
  else
    {
      echo "---"
      echo "services:"
      echo "$services" | yq eval '.' - | sed 's/^/  /'
      echo ""
      echo "volumes:"
      echo "$volumes" | yq eval '.' - | sed 's/^/  /'
      echo ""
      echo "secrets:"
      echo "$secrets" | yq eval '.' - | sed 's/^/  /'
      echo ""
      echo "networks:"
      echo "$networks" | yq eval '.' - | sed 's/^/  /'
    } > "$target_file"
    log_info "Merged $source_file into $target_file"
  fi
}

# Function: backup_existing_file
# Backup a single source file into the target directory.
# The backup filename is source filename + timestamp suffix.
# Keeps only a limited number of backups (default 2).
# Supports DRY_RUN and logs all actions.
# ─────────────────────────────────────────────────────────────
backup_existing_file() {
  local src_file="$1"
  local target_dir="$2"
  local max_backups="${3:-2}"

  # Return immediately if source file does not exist
  if [[ ! -f "$src_file" ]]; then
    return 0
  fi

  # Ensure target directory exists
  ensure_dir_exists "$target_dir"

  # Extract base filename from source file path
  local base_filename
  base_filename=$(basename -- "$src_file")

  # Create backup filename with timestamp suffix
  local timestamp
  timestamp=$(date -u +%Y%m%d%H%M%S)
  local backup_file="${target_dir}/${base_filename}.${timestamp}"

  # Copy source file to backup file using copy_file function
  if ! copy_file "$src_file" "$backup_file"; then
    log_error "Backup failed: could not copy $src_file to $backup_file"
    return 1
  fi
  log_info "Backed up $src_file to $backup_file"

  # Cleanup old backups, keep only $max_backups newest files for this base filename
  mapfile -t backups < <(ls -1tr "${target_dir}/${base_filename}."* 2>/dev/null)

  local num_to_delete=$(( ${#backups[@]} - max_backups ))
  if (( num_to_delete > 0 )); then
    for ((i=0; i<num_to_delete; i++)); do
      log_info "Deleting old backup file: ${backups[i]}"
      if [[ "$DRY_RUN" == true ]]; then
        log_info "Dry-run: would delete '${backups[i]}'"
      else
        rm -f -- "${backups[i]}"
      fi
    done
  fi
}

# Function: make_scripts_executable
# Recursively set +x permission on all scripts/files in a target directory.
# Skips if directory doesn't exist or no files found.
# Supports DRY_RUN to simulate the operation.
# ───────────────────────────────────────────────────────────────────────
make_scripts_executable() {
  local target_dir="$1"

  # Check argument
  if [[ -z "$target_dir" ]]; then
    log_error "Missing argument: target_dir"
    return 1
  fi

  if [[ ! -d "$target_dir" ]]; then
    log_info "Target directory '$target_dir' does not exist, skipping chmod +x"
    return 0
  fi

  local found_any=false

  while IFS= read -r -d '' file; do
    found_any=true
    if [[ "$DRY_RUN" == true ]]; then
      log_info "Dry-run: would chmod +x '$file'"
    else
      chmod +x "$file" || {
        log_error "Failed to chmod +x '$file'"
        return 1
      }
      log_info "Set executable permission on '$file'"
    fi
  done < <(find "$target_dir" -type f -print0)

  if [[ "$found_any" == false ]]; then
    log_info "No files found in '$target_dir' to make executable"
  fi

  return 0
}

# Function: get_env_value_from_file
# Reads a key from an .env file, strips inline comments, and trims quotes.
# ───────────────────────────────────────────────────────────────────────
get_env_value_from_file() {
  local key="$1"
  local file="$2"
  local line value

  if [[ ! -f "$file" ]]; then
    log_error "Environment file not found: $file"
    return 1
  fi

  if ! line=$(grep -E "^[[:space:]]*$key=" "$file" | tail -n1); then
    log_error "Key $key not present in $file"
    return 1
  fi

  value=${line#*=}
  value=${value%%#*}
  value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

  if [[ ${#value} -ge 2 ]]; then
    if [[ ${value:0:1} == "\"" && ${value: -1} == "\"" ]]; then
      value=${value:1:-1}
    elif [[ ${value:0:1} == "'" && ${value: -1} == "'" ]]; then
      value=${value:1:-1}
    fi
  fi

  printf '%s\n' "$value"
}

# ──────────────────────────────────────────────────────────────────────────────
# Main Function
# ──────────────────────────────────────────────────────────────────────────────

# Function: parse_args
# Parses command-line arguments, sets globals and logging
# ───────────────────────────────────────
parse_args() {
  TMPDIR=""
  TARGET_DIR=""
  INITIAL_RUN=false
  DEBUG=false
  DRY_RUN=false
  FORCE=false
  UPDATE=false
  DELETE_VOLUMES=false
  GENERATE_PASSWORD=false
  GP_LEN=""
  GP_FILE=""

  while (( $# )); do
    case "$1" in
      --debug)
        DEBUG=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --update)
        UPDATE=true
        shift
        ;;
      --delete_volumes)
        DELETE_VOLUMES=true
        shift
        ;;
      --generate_password)
        GENERATE_PASSWORD=true
        shift
        # Parse optional args for --generate_password
        for _ in 1 2; do
          if [[ $# -eq 0 ]]; then break; fi
          if [[ "${1:-}" == --* ]]; then break; fi
          if [[ "$1" =~ ^[0-9]+$ ]]; then
            GP_LEN="$1"
          else
            GP_FILE="$1"
          fi
          shift
        done
        ;;
      -*)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        if [[ -z "${TARGET_DIR:-}" ]]; then
          TARGET_DIR="${1%/}"
          shift
          if [[ "$TARGET_DIR" == */ || \
                "$TARGET_DIR" == /* || \
                "$TARGET_DIR" == *".."* || \
                "$TARGET_DIR" =~ //|\\ ]]; then
            log_error "Invalid target directory: '$TARGET_DIR'"
            log_error "→ No trailing slash, no absolute path, no '..', no double slashes or backslashes allowed."
            exit 1
          fi
        else
          log_error "Multiple folder arguments are not supported."
          usage
          exit 1
        fi
        ;;
    esac
  done

  log_debug "Debug mode enabled"
  if [[ "$DRY_RUN" == true ]]; then log_info "Dry-run mode enabled"; fi

  setup_logging "2"

  TARGET_DIR="${SCRIPT_DIR}/${TARGET_DIR:-}"

  if [[ ! -d "$TARGET_DIR" ]]; then
    log_error "'$TARGET_DIR' does not exist!"
    exit 1
  fi

  log_debug "Target directory: $TARGET_DIR"

}

# Function: check_dependencies
# Verifies specified dependencies are installed
# ───────────────────────────────────────
check_dependencies() {
  local deps=($1)
  local failed=0

  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      log_warn "$dep is not installed."

      if [[ "$DRY_RUN" == true ]]; then
        log_info "Dry-run: skipping $dep installation prompt."
        failed=1
        continue
      fi

      read -r -p "Install $dep now? [y/N]: " install
      if [[ "$install" =~ ^[Yy]$ ]]; then
        if [[ "$dep" == "yq" ]]; then
          install_dependency "$dep" "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
        else
          install_dependency "$dep"
        fi
      else
        log_error "$dep is required. Aborting."
        return 1
      fi
    else
      log_debug "$dep is already installed."
    fi
  done

  if [[ $failed -eq 1 ]]; then
    return 1
  fi

  return 0
}

# Function: clone_sparse_checkout
# Clone Repo with Sparse Checkout
# ───────────────────────────────────────
clone_sparse_checkout() {
  local repo_url="$1"
  local branch="${2:-main}"
  REPO_SUBFOLDER="$3"
  local lockfile="${TARGET_DIR}/.${SCRIPT_BASE}.conf/.$REPO_SUBFOLDER.lock"

  # Ensure required parameters are provided
  [[ -z "$repo_url" || -z "$REPO_SUBFOLDER" ]] && {
    log_error "Missing repo_url or REPO_SUBFOLDER."
    return 1
  }

  if [[ "$REPO_SUBFOLDER" == /* || "$REPO_SUBFOLDER" == *".."* ]]; then
    log_error "Invalid folder path: '$REPO_SUBFOLDER'"
    return 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_info "Dry-run: skipping git clone."
    return 0
  fi

  TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/${SCRIPT_BASE}.XXXXXX")
  log_debug "Created temp dir: $TMPDIR"

  git clone --quiet --filter=blob:none --no-checkout "$repo_url" "$TMPDIR" || {
    log_error "Failed to clone repo."
    return 1
  }

  if ! git -C "$TMPDIR" ls-tree -d --name-only "$branch":"$REPO_SUBFOLDER" &>/dev/null; then
    log_error "Folder '$REPO_SUBFOLDER' not found in branch '$branch'."
    return 1
  fi

  git -C "$TMPDIR" sparse-checkout init --cone &>/dev/null || {
    log_error "Sparse checkout init failed."
    return 1
  }

  git -C "$TMPDIR" sparse-checkout set "$REPO_SUBFOLDER" &>/dev/null || {
    log_error "Sparse checkout set failed."
    return 1
  }

  git -C "$TMPDIR" checkout "$branch" &>/dev/null || {
    log_error "Failed to checkout branch '$branch'."
    return 1
  }

  if [[ ! -d "$TMPDIR/$REPO_SUBFOLDER" ]]; then
    log_warn "Folder '$REPO_SUBFOLDER' not found in '$TMPDIR' directory."
  else
    log_ok "Checked out folder '$REPO_SUBFOLDER' successfully."
  fi

  local revision
  revision=$(git -C "$TMPDIR" rev-parse HEAD 2>/dev/null) || {
    log_error "Failed to get git revision."
    return 1
  }

  # Check existing lockfile
  local locked_rev=""
  if [[ -f "$lockfile" ]]; then
    locked_rev=$(<"$lockfile")
    if [[ "$locked_rev" == "$revision" ]]; then
      log_ok "Template already up to date (rev: $revision)"
    elif [[ "$FORCE" == false ]]; then
      log_info "Template update available. Run with --force to apply. Locked: $locked_rev, Current: $revision"
    fi
  else
    INITIAL_RUN=true
    log_info "No lockfile found. Assuming initial clone."
  fi

  # Write lockfile if forced or initial run
  if [[ "$INITIAL_RUN" == true || "$FORCE" == true ]] && [[ -z "$locked_rev" || "$locked_rev" != "$revision" ]]; then
    echo "$revision" > "$lockfile" || {
      log_error "Failed to write lockfile $lockfile"
      return 1
    }
    log_ok "Wrote template revision to $lockfile"
  fi
}

# Function: copy_required_services
# Copy and merge all required service files and configurations
# ───────────────────────────────────────
copy_required_services() {
  local app_compose="${TARGET_DIR}/docker-compose.app.yaml"
  local app_env="${TARGET_DIR}/app.env"
  local main_compose="${TARGET_DIR}/docker-compose.main.yaml"
  local main_env="${TARGET_DIR}/.env"
  local backup_dir="${TARGET_DIR}/.${SCRIPT_BASE}.conf/.backups"
  local -A seen_vars=()

  if [[ ! -f "$app_compose" ]]; then
    log_error "File '$app_compose' doesn't exist"
    return 1
  fi

  # Parsing $app_compose
  log_info "Parsing $app_compose for required services..."
  
  local requires=$(yq '.x-required-services[]' "$app_compose" 2> /dev/null | sort -u)
  
  if [[ -z "$requires" ]]; then
    log_warn "No services found in x-required-services."
  else
    log_info "Found required services:"
    while IFS= read -r service; do
      log_info "   • ${MAGENTA}${service}${RESET}"
    done <<< "$requires"
  fi

  # Copy all required files for the services (docker-compose.*.yaml, /secrets/*, /scripts/*)
  if [[ "$DRY_RUN" == true ]]; then
    log_info "Dry-run: skipping of copying required services."
    return 0
  fi

  # If app.env not exist move it from the initial .env
  if [[ -f "$main_env" && ! -f "$app_env" ]]; then
    mv "$main_env" "$app_env"
    log_info "Found legacy $main_env file – renamed to $app_env"
  elif [[ -f "$main_env" && -f "$app_env" ]]; then
    rm -f "$main_env"
    log_debug "Both $main_env and $app_env exist – deleted $main_env"
  fi

  process_merge_file "${app_env}" "${main_env}" seen_vars
  process_merge_yaml_file "${app_compose}" "${main_compose}"

  if [[ "$FORCE" == true ]]; then
    backup_existing_file "${app_compose}" "${backup_dir}"
    backup_existing_file "${app_env}" "${backup_dir}"
  fi

  for service in $requires; do
    local template_dir="${TMPDIR}/${REPO_SUBFOLDER}"
    local template_compose_file="${template_dir}/${service}/docker-compose.${service}.yaml"
    local template_env_file="${template_dir}/${service}/.env"
    local targetdir_compose_file="${TARGET_DIR}/docker-compose.${service}.yaml"

    log_info "Processing required service: ${MAGENTA}${service}${RESET}"

    if [[ "$FORCE" == true ]]; then
      backup_existing_file "${targetdir_compose_file}" "${backup_dir}"
    fi

    if [[ "$INITIAL_RUN" == true || "$FORCE" == true ]]; then
      merge_subfolders_from "${template_dir}" "${service}" "${TARGET_DIR}"
      copy_file "${template_compose_file}" "${TARGET_DIR}"
    fi

    process_merge_file "${template_env_file}" "${main_env}" seen_vars
    process_merge_yaml_file "${targetdir_compose_file}" "${main_compose}"

  done

  log_ok "All required services processed"

  if [[ "$FORCE" == true ]]; then
    log_ok "All templates backuped and updated (replaced)!"
  fi
}

# Function: set_permissions
# Sets ownership and permissions (700) recursively on directories.
# Creates directories if they do not exist.
# Directories are relative to TARGET_DIR.
# Respects FORCE flag to re-apply permissions on existing directories.
# Arguments:
#   $1 - comma-separated list of directory paths (relative to TARGET_DIR)
#   $2 - user for ownership
#   $3 - group for ownership
# ───────────────────────────────────────────────────────────────────────
set_permissions() {
  local dirs="$1"
  local user="$2"
  local group="$3"
  local old_ifs=$IFS
  IFS=','

  for dir in $dirs; do
    dir="${dir#"${dir%%[![:space:]]*}"}"
    dir="${dir%"${dir##*[![:space:]]}"}"
    dir="$TARGET_DIR/$dir"

    if [[ "$FORCE" == true || "$INITIAL_RUN" == true ]]; then
      ensure_dir_exists "$dir"

      if chown -R "${user}:${group}" "$dir"; then
         log_info "Setting ownership ${user}:${group} on $dir"
      else
        log_error "chown failed on $dir"
        return 1
      fi

      if chmod -R 700 "$dir"; then
         log_info "Setting permissions 700 on $dir"
      else
        log_error "chmod 700 failed on $dir"
        return 1
      fi
    else
      log_info "Directory $dir already exist. Run with --force to apply the permissions!"
    fi
  done

  IFS=$old_ifs
}

# Function: pull_docker_images
# Pull latest docker images from merged compose file and show tag + image ID before and after pull.
# Arguments:
#   $1 - path to merged compose YAML file
#   $2 - path to env file (to load variables)
# Logs all steps, supports DRY_RUN.
# ───────────────────────────────────────
pull_docker_images() {
  local merged_compose_file="$1"
  local env_file="$2"

  if [[ -z "$merged_compose_file" || -z "$env_file" ]]; then
    log_error "Missing arguments: merged_compose_file and env_file are required."
    return 1
  fi

  if [[ ! -f "$merged_compose_file" ]]; then
    log_error "Merged compose file '$merged_compose_file' does not exist."
    return 1
  fi

  if [[ -f "$env_file" ]]; then
    log_debug "Loading environment variables from $env_file"
    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a
  else
    log_warn "Env file '$env_file' not found. Cannot resolve image variables."
    return 1
  fi

  local services image_raw image image_id_before image_id_after svc
  local image_updated=false

  services=$(yq e '.services | keys | .[]' "$merged_compose_file")
  if [[ -z "$services" ]]; then
    log_warn "No services found in $merged_compose_file"
    return 0
  fi

  for svc in $services; do
    image_raw=$(yq e ".services.\"$svc\".image" "$merged_compose_file")
    image=$(eval echo "$image_raw")

    if [[ "$image" != "null" && -n "$image" ]]; then
      # Get image ID before pull (empty if not found)
      image_id_before=$(docker image inspect --format='{{.Id}}' "$image" 2>/dev/null || echo "none")

      log_info "Service '${MAGENTA}${svc}${RESET}' - Image tag: $image"
      log_debug "Image ID before pull: $image_id_before"

      if [[ "${DRY_RUN:-false}" == true ]]; then
        log_info "Dry-run: would pull image '$image'"
        continue
      fi

      if docker pull "$image" --quiet >/dev/null 2>&1; then
        # Get image ID after pull (empty if not found)
        image_id_after=$(docker image inspect --format='{{.Id}}' "$image" 2>/dev/null || echo "none")

        log_info "Pulled image '$image' successfully."
        log_debug "Image ID after pull:  $image_id_after"

        if [[ "$image_id_before" == "$image_id_after" ]]; then
          log_ok "Image was already up to date."
        else
          log_ok "Image updated."
          image_updated=true
        fi
      else
        log_error "Failed to pull image '$image'."
      fi
    else
      log_warn "No image defined for service '$svc', skipping."
    fi
  done

  if [[ "$image_updated" == true ]]; then
    if [[ "${DRY_RUN:-false}" == true ]]; then
      log_info "Dry-run: would restart Docker Compose services due to image updates."
    else
      log_info "Restarting services due to updated images..."

      if docker compose --env-file "$env_file" -f "$merged_compose_file" down --remove-orphans; then
        log_info "Services shut down successfully."
      else
        log_error "Failed to shut down services."
        return 1
      fi

      if docker compose --env-file "$env_file" -f "$merged_compose_file" up -d; then
        log_ok "Services restarted with updated images."
      else
        log_error "Failed to start services."
        return 1
      fi
    fi
  else
    log_info "No services restarted, all images were up to date."
  fi
}

# Function: delete_docker_volumes
# Deletes Docker volumes defined in the given compose file.
# Stops the docker-compose project first if running (interactive prompt unless --force).
# Arguments:
#   $1 - path to merged compose YAML file
# Supports DRY_RUN and FORCE.
# ───────────────────────────────────────
delete_docker_volumes() {
  local compose_file="$1"

  if [[ -z "$compose_file" ]]; then
    log_error "Missing argument: compose_file is required."
    return 1
  fi

  if [[ ! -f "$compose_file" ]]; then
    log_error "Compose file '$compose_file' does not exist."
    return 1
  fi

  local project_name
  project_name="$(basename "$(dirname "$compose_file")")"
  local project_name_lc
  project_name_lc="$(echo "$project_name" | tr '[:upper:]' '[:lower:]')"

  # Check if project is running
  local running_containers
  running_containers=$(docker ps --filter "label=com.docker.compose.project=$project_name_lc" --format '{{.ID}}')

  if [[ -n "$running_containers" ]]; then
    if [[ "${FORCE:-false}" == true ]]; then
      log_warn "Docker Compose project '$project_name_lc' is running. Forcing shutdown."
    else
      read -r -p "Docker Compose project '$project_name_lc' is running. Stop it now? [y/N]: " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "Aborting volume deletion."
        return 0
      fi
    fi

    if [[ "${DRY_RUN:-false}" == true ]]; then
      log_info "Dry-run: would run 'docker compose down' for project '$project_name_lc'"
    else
      log_info "Stopping Docker Compose project '$project_name_lc'"
      docker compose -p "$project_name_lc" -f "$compose_file" down || {
        log_error "Failed to stop Compose project '$project_name_lc'"
        return 1
      }
    fi
  fi

  log_info "Deleting Docker volumes defined in $compose_file for project '$project_name_lc'"

  local volumes
  volumes=$(yq e '.volumes | keys | .[]' "$compose_file" 2>/dev/null || true)

  if [[ -z "$volumes" ]]; then
    log_warn "No volumes defined in $compose_file"
    return 0
  fi

  local vol full_volume_name
  for vol in $volumes; do
    full_volume_name="${project_name_lc}_${vol}"
    full_volume_name="$(echo "$full_volume_name" | tr '[:upper:]' '[:lower:]')"

    if docker volume inspect "$full_volume_name" >/dev/null 2>&1; then
      if [[ "${DRY_RUN:-false}" == true ]]; then
        log_info "Dry-run: would remove volume '$full_volume_name'"
      else
        log_debug "Removing volume: $full_volume_name"
        if docker volume rm "$full_volume_name" >/dev/null 2>&1; then
          log_ok "Removed $full_volume_name"
        else
          log_error "Failed to remove $full_volume_name"
        fi
      fi
    else
      log_warn "Volume '$full_volume_name' does not exist, skipping"
    fi
  done
}

# Function: generate_password
# Generate a YAML-compatible password and write it into files under a source directory.
# Arguments:
#   $1 - source directory (mandatory)
#   $2 - (optional) password length (defaults to 100 if not numeric or not set)
#   $3 - (optional) specific filename (only that file will be written)
# Notes:
#   - Overwrites existing files
#   - Uses DRY_RUN if set to true
#   - Generates passwords with YAML-safe characters (no ', ", \)
# ───────────────────────────────────────
generate_password() {
  local src_dir="$1"
  local len_arg="$2"
  local file_arg="$3"

  if [[ -z "$src_dir" ]]; then
    log_error "Missing source directory as first argument."
    return 1
  fi

  if [[ ! -d "$src_dir" ]]; then
    log_error "Source directory '$src_dir' does not exist."
    return 1
  fi

  local pw_length=100
  if [[ "$len_arg" =~ ^[0-9]+$ ]]; then
    pw_length="$len_arg"
  elif [[ -n "$len_arg" && -z "$file_arg" ]]; then
    # len_arg is not numeric, so treat it as filename
    file_arg="$len_arg"
  fi

  local files=()
  if [[ -n "$file_arg" ]]; then
    files+=("$src_dir/$file_arg")
  else
    while IFS= read -r -d '' f; do
      files+=("$f")
    done < <(find "$src_dir" -maxdepth 1 -type f -print0)
  fi

  local charset='A-Za-z0-9_=\-,.:/@()[]{}<>?!^*|#$~'
  local pw
  for f in "${files[@]}"; do
    pw=$(LC_ALL=C tr -dc "$charset" </dev/urandom | head -c "$pw_length")
    if [[ "$DRY_RUN" == true ]]; then
      log_info "Dry-run: would write password of length $pw_length to $(basename "$f")"
    else
      printf "%s" "$pw" > "$f"
      log_info "Wrote password of length $pw_length → $(basename "$f")"
    fi
  done
}

# Function: load_permissions_env
# Loads APP_UID, APP_GID, and DIRECTORIES into the current shell.
# Arguments:
#   $1 - path to merged .env file
# ───────────────────────────────────────────────────────────────────────
load_permissions_env() {
  local env_file="${1:-${TARGET_DIR}/.env}"

  if [[ -z "${APP_UID:-}" ]]; then
    APP_UID="$(get_env_value_from_file "APP_UID" "$env_file")" || return 1
  fi

  if [[ -z "${APP_GID:-}" ]]; then
    APP_GID="$(get_env_value_from_file "APP_GID" "$env_file")" || return 1
  fi

  if [[ -z "${DIRECTORIES:-}" ]]; then
    DIRECTORIES="$(get_env_value_from_file "DIRECTORIES" "$env_file")" || return 1
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Main Execution
# ──────────────────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  if [[ "${UPDATE:-false}" == true ]]; then
    pull_docker_images "${TARGET_DIR}/docker-compose.main.yaml" "${TARGET_DIR}/.env"
  elif [[ "${DELETE_VOLUMES:-false}" == true ]]; then
    delete_docker_volumes "${TARGET_DIR}/docker-compose.main.yaml"
  elif [[ "${GENERATE_PASSWORD:-false}" == true ]]; then
    generate_password "${TARGET_DIR}/secrets" "${GP_LEN}" "${GP_FILE}"
  elif [[ -n "$TARGET_DIR" ]]; then
    check_dependencies "git yq rsync"
    clone_sparse_checkout "https://github.com/saervices/Docker.git" "main" "templates"
    copy_required_services

    if [[ "${INITIAL_RUN:-false}" == true ]]; then
      generate_password "${TARGET_DIR}/secrets" "${GP_LEN}" "${GP_FILE}"
    fi
    
    make_scripts_executable "${TARGET_DIR}/scripts"

    if load_permissions_env "${TARGET_DIR}/.env"; then
      log_info "Loading variables from "${TARGET_DIR}/.env""
      set_permissions "$DIRECTORIES" "$APP_UID" "$APP_GID"
    else
      log_warn "Skipping permission adjustments because required environment values are missing."
    fi

    setup_cleanup_trap
    log_ok "Script completed successfully."
  else
    return 1
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Script Entry Point
# ──────────────────────────────────────────────────────────────────────────────
main "$@" || {
  exit 1
}