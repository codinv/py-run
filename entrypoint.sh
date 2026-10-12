#!/bin/bash
set -euo pipefail

log() { echo "[py-run] $*"; }

# смонтирован ли каталог (читаем mountinfo, не зависим от утилит)
is_mounted() { awk -v p="$1" '$5 == p { f = 1 } END { exit !f }' "${MOUNTINFO:-/proc/self/mountinfo}"; }

if [ -z "${DATA_DIR:-}" ]; then
    DATA_DIR=/data
    if ! is_mounted /data; then
        if is_mounted /app; then
            # старая схема (-v ./:/app): продолжаем работать из /app, но просим перейти на /data
            DATA_DIR=/app
            log "WARNING: legacy mount /app detected. Please switch to './data:/data' (see README)."
            log "WARNING: venv and requirements.txt will be created inside /app."
        else
            log "WARNING: /data is not a mounted volume - script, venv and packages will be lost when the container is recreated. Use '-v ./data:/data'."
        fi
    fi
fi
DEFAULTS_DIR="${DEFAULTS_DIR:-/opt/py-run}"
VENV_DIR="$DATA_DIR/venv"
REQ_FILE="$DATA_DIR/requirements.txt"
VENV_STAMP="$VENV_DIR/.py-run-env"          # версия python + архитектура, для которых собран venv
REQ_STAMP="$VENV_DIR/.requirements.sha256"  # хэш уже установленного requirements.txt

# --- часовой пояс --------------------------------------------------------
if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/$TZ" ]; then
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
fi

mkdir -p "$DATA_DIR"
cd "$DATA_DIR"

# --- какой скрипт запускаем (путь относительно /data) --------------------
SCRIPT="${1:-${PY_SCRIPT:-./myscript.py}}"

# --- первый запуск: кладём в пустой /data шаблоны ------------------------
case "$SCRIPT" in
    myscript.py|./myscript.py|"$DATA_DIR/myscript.py")
        if [ ! -e "$SCRIPT" ] && [ -f "$DEFAULTS_DIR/myscript.py" ]; then
            cp "$DEFAULTS_DIR/myscript.py" "$SCRIPT"
            log "Created default $SCRIPT"
        fi
        ;;
esac

if [ ! -e "$REQ_FILE" ]; then
    cat > "$REQ_FILE" <<'EOF'
# Список Python-модулей (по одному в строке), например:
# requests
# aiogram==3.*
#
# После изменения файла просто перезапустите контейнер:
#   docker compose restart
EOF
    log "Created template $REQ_FILE"
fi

if [ ! -f "$SCRIPT" ]; then
    echo "Error: Python script '$SCRIPT' not found in $DATA_DIR!" >&2
    exit 1
fi

# --- venv: создаём один раз, живёт в volume ------------------------------
WANT_ENV="py$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')-$(uname -m)"

if [ ! -x "$VENV_DIR/bin/python" ] || [ "$(cat "$VENV_STAMP" 2>/dev/null || true)" != "$WANT_ENV" ]; then
    if [ -e "$VENV_DIR" ]; then
        log "venv is missing/broken or built for another Python/arch -> recreating ($WANT_ENV)"
    else
        log "Creating venv in $VENV_DIR ($WANT_ENV)"
    fi
    rm -rf "$VENV_DIR"
    python3 -m venv "$VENV_DIR"
    echo "$WANT_ENV" > "$VENV_STAMP"   # пишем последним: нет файла = venv не доделан
fi

# --- зависимости: ставим только если requirements.txt изменился ----------
REQ_HASH="$(sha256sum "$REQ_FILE" | cut -d' ' -f1)"

if [ "$(cat "$REQ_STAMP" 2>/dev/null || true)" = "$REQ_HASH" ]; then
    log "requirements.txt unchanged, skipping pip install"
else
    log "Installing packages from requirements.txt"
    if ! "$VENV_DIR/bin/python" -m pip install -r "$REQ_FILE"; then
        echo "Error: pip install failed, check $REQ_FILE" >&2
        exit 1
    fi
    echo "$REQ_HASH" > "$REQ_STAMP"    # хэш пишем только после успешной установки
fi

# --- запуск --------------------------------------------------------------
export VIRTUAL_ENV="$VENV_DIR"
export PATH="$VENV_DIR/bin:$PATH"

log "Running: $SCRIPT"
exec python -u "$SCRIPT"
