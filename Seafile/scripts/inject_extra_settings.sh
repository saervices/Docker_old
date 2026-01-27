#!/bin/bash
# ==============================================================================
# Seafile Extra Settings Injector
# ==============================================================================
# Automatically injects "from seahub_settings_extra import *" into seahub_settings.py
# if not already present. This ensures custom OAuth/Authentik settings are loaded.
#
# Usage: Run this script before Seafile starts (in entrypoint or as init script)
# ==============================================================================

set -euo pipefail

SEAHUB_SETTINGS="/shared/seafile/conf/seahub_settings.py"
IMPORT_LINE="from seahub_settings_extra import *"

# Wait for seahub_settings.py to exist (in case Seafile creates it on first run)
TIMEOUT=30
ELAPSED=0
while [[ ! -f "$SEAHUB_SETTINGS" ]] && [[ $ELAPSED -lt $TIMEOUT ]]; do
    echo "[INFO] Waiting for $SEAHUB_SETTINGS to be created..."
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

if [[ ! -f "$SEAHUB_SETTINGS" ]]; then
    echo "[ERROR] $SEAHUB_SETTINGS not found after ${TIMEOUT}s. Cannot inject extra settings."
    exit 1
fi

# Check if import line already exists
if grep -qF "$IMPORT_LINE" "$SEAHUB_SETTINGS"; then
    echo "[INFO] Extra settings import already present in $SEAHUB_SETTINGS"
    exit 0
fi

# Inject import at the end of the file
echo "" >> "$SEAHUB_SETTINGS"
echo "# Import extra settings" >> "$SEAHUB_SETTINGS"
echo "$IMPORT_LINE" >> "$SEAHUB_SETTINGS"

echo "[SUCCESS] Injected extra settings import into $SEAHUB_SETTINGS"
