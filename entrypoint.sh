#!/bin/bash
set -eo pipefail

[ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/$TZ" ] && {
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
}

SCRIPT="${1:-${PY_SCRIPT:-./myscript.py}}"

if [ -f "$SCRIPT" ]; then
    echo "Running: $SCRIPT"
else
    echo "Error: Python script '$SCRIPT' not found!" >&2
    exit 1
fi

exec python3 -u "$SCRIPT"
